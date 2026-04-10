package com.washhub.api.domain.auth.service;

import com.washhub.api.domain.auth.dto.TokenResponse;
import com.washhub.api.domain.member.entity.Member;
import com.washhub.api.domain.member.entity.MemberStatus;
import com.washhub.api.domain.member.entity.SocialAccount;
import com.washhub.api.domain.member.entity.SocialProvider;
import com.washhub.api.domain.member.repository.MemberRepository;
import com.washhub.api.domain.member.repository.SocialAccountRepository;
import com.washhub.api.global.error.exception.ErrorCode;
import com.washhub.api.global.error.exception.NotAcceptableException;
import com.washhub.api.global.security.JwtTokenProvider;
import com.washhub.api.infra.kakao.KakaoApiClient;
import com.washhub.api.infra.kakao.KakaoUserInfo;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Optional;

@Slf4j
@RequiredArgsConstructor
@Service
public class AuthService {

    private final KakaoApiClient kakaoApiClient;
    private final MemberRepository memberRepository;
    private final SocialAccountRepository socialAccountRepository;
    private final JwtTokenProvider jwtTokenProvider;

    /**
     * 카카오 로그인 처리
     * - 기존 회원: 로그인 → JWT 발급
     * - 신규 회원: 회원가입 → JWT 발급
     */
    @Transactional
    public TokenResponse kakaoLogin(String kakaoAccessToken) {
        // 1. 카카오 API로 사용자 정보 조회
        KakaoUserInfo kakaoUserInfo = kakaoApiClient.getUserInfo(kakaoAccessToken);

        // 2. 소셜 계정 조회
        Optional<SocialAccount> persistSocialAccount = socialAccountRepository
                .findByProviderAndProviderId(SocialProvider.KAKAO, kakaoUserInfo.getProviderId());

        boolean isNewMember = false;
        Member persistMember;

        if (persistSocialAccount.isPresent()) {
            // 기존 회원 로그인
            persistMember = persistSocialAccount.get().getMember();
            if (!persistMember.isActive()) {
                throw new NotAcceptableException(ErrorCode.FORBIDDEN, "탈퇴한 회원입니다."); // TODO-minam
            }
            log.info("기존 회원 로그인: memberId={}", persistMember.getId());
        } else {
            // 신규 회원가입
            persistMember = Member.builder()
                    .nickname(null) // 닉네임은 별도 설정
                    .profileImageUrl(kakaoUserInfo.getProfileImageUrl())
                    .build();
            persistMember = memberRepository.save(persistMember);

            SocialAccount socialAccount = SocialAccount.builder()
                    .member(persistMember)
                    .provider(SocialProvider.KAKAO)
                    .providerId(kakaoUserInfo.getProviderId())
                    .build();
            socialAccountRepository.save(socialAccount);

            isNewMember = true;
            log.info("신규 회원가입: memberId={}", persistMember.getId());
        }

        // 3. JWT 토큰 발급
        String accessToken = jwtTokenProvider.createAccessToken(persistMember.getId());
        String refreshToken = jwtTokenProvider.createRefreshToken(persistMember.getId());

        return TokenResponse.builder()
                .accessToken(accessToken)
                .refreshToken(refreshToken)
                .isNewMember(isNewMember)
                .build();
    }

    /**
     * Refresh Token으로 Access Token 재발급
     */
    @Transactional(readOnly = true)
    public TokenResponse refreshToken(String refreshToken) {
        if (!jwtTokenProvider.validateToken(refreshToken)) {
            throw new NotAcceptableException(ErrorCode.INVALID_TOKEN, "유효하지 않은 Refresh Token입니다."); // TODO-minam
        }

        Long memberId = jwtTokenProvider.getMemberId(refreshToken);
        Member persistMember = memberRepository.findById(memberId)
                .filter(Member::isActive)
                .orElseThrow(() -> new NotAcceptableException(ErrorCode.NOT_FOUND, "회원을 찾을 수 없습니다.")); // TODO-minam

        String newAccessToken = jwtTokenProvider.createAccessToken(persistMember.getId());
        String newRefreshToken = jwtTokenProvider.createRefreshToken(persistMember.getId());

        return TokenResponse.builder()
                .accessToken(newAccessToken)
                .refreshToken(newRefreshToken)
                .isNewMember(false)
                .build();
    }

    /**
     * 회원 탈퇴
     */
    @Transactional
    public void withdraw(Long memberId) {
        Member persistMember = memberRepository.findById(memberId)
                .orElseThrow(() -> new NotAcceptableException(ErrorCode.NOT_FOUND, "회원을 찾을 수 없습니다.")); // TODO-minam

        // 소셜 계정 삭제
        socialAccountRepository.deleteAllByMemberId(persistMember.getId());

        // 회원 상태 변경 + 개인정보 삭제
        persistMember.withdraw();

        log.info("회원 탈퇴 처리 완료: memberId={}", memberId);
    }
}
