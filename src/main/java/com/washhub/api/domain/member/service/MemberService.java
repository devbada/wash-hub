package com.washhub.api.domain.member.service;

import com.washhub.api.domain.member.dto.MemberResponse;
import com.washhub.api.domain.member.dto.MemberUpdateRequest;
import com.washhub.api.domain.member.entity.Member;
import com.washhub.api.domain.member.repository.MemberRepository;
import com.washhub.api.global.error.exception.ErrorCode;
import com.washhub.api.global.error.exception.NotAcceptableException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Slf4j
@RequiredArgsConstructor
@Service
public class MemberService {

    private final MemberRepository memberRepository;

    /**
     * 내 정보 조회
     */
    @Transactional(readOnly = true)
    public MemberResponse getMyInfo(Long memberId) {
        Member persistMember = memberRepository.findById(memberId)
                .filter(Member::isActive)
                .orElseThrow(() -> new NotAcceptableException(ErrorCode.NOT_FOUND, "회원을 찾을 수 없습니다.")); // TODO-minam

        return MemberResponse.from(persistMember);
    }

    /**
     * 내 정보 수정 (닉네임, 프로필 이미지)
     */
    @Transactional
    public MemberResponse updateMyInfo(Long memberId, MemberUpdateRequest request) {
        Member persistMember = memberRepository.findById(memberId)
                .filter(Member::isActive)
                .orElseThrow(() -> new NotAcceptableException(ErrorCode.NOT_FOUND, "회원을 찾을 수 없습니다.")); // TODO-minam

        // 닉네임 중복 검사 (본인 닉네임과 다른 경우에만)
        if (!request.getNickname().equals(persistMember.getNickname())
                && memberRepository.existsByNickname(request.getNickname())) {
            throw new NotAcceptableException("이미 사용 중인 닉네임입니다."); // TODO-minam
        }

        persistMember.updateProfile(request.getNickname(), request.getProfileImageUrl());
        log.info("회원 정보 수정 완료: memberId={}", memberId);

        return MemberResponse.from(persistMember);
    }

    /**
     * 닉네임 중복 확인
     */
    @Transactional(readOnly = true)
    public boolean checkNicknameDuplicate(String nickname) {
        return memberRepository.existsByNickname(nickname);
    }
}
