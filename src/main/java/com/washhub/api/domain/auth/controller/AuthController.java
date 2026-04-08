package com.washhub.api.domain.auth.controller;

import com.washhub.api.domain.auth.dto.KakaoLoginRequest;
import com.washhub.api.domain.auth.dto.RefreshRequest;
import com.washhub.api.domain.auth.dto.TokenResponse;
import com.washhub.api.domain.auth.service.AuthService;
import com.washhub.api.global.common.dto.ApiResponse;
import com.washhub.api.global.security.SecurityUtil;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import javax.validation.Valid;

@RequiredArgsConstructor
@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {

    private final AuthService authService;

    /**
     * 카카오 로그인
     * POST /api/v1/auth/kakao
     */
    @PostMapping("/kakao")
    public ResponseEntity<ApiResponse<TokenResponse>> kakaoLogin(
            @Valid @RequestBody KakaoLoginRequest request) {
        TokenResponse tokenResponse = authService.kakaoLogin(request.getAccessToken());
        return ResponseEntity.ok(ApiResponse.success(tokenResponse));
    }

    /**
     * 토큰 갱신
     * POST /api/v1/auth/refresh
     */
    @PostMapping("/refresh")
    public ResponseEntity<ApiResponse<TokenResponse>> refreshToken(
            @Valid @RequestBody RefreshRequest request) {
        TokenResponse tokenResponse = authService.refreshToken(request.getRefreshToken());
        return ResponseEntity.ok(ApiResponse.success(tokenResponse));
    }

    /**
     * 로그아웃
     * POST /api/v1/auth/logout
     */
    @PostMapping("/logout")
    public ResponseEntity<ApiResponse<Void>> logout() {
        // 클라이언트에서 토큰 삭제 처리
        // TODO-minam: Redis 기반 토큰 블랙리스트 추가 검토
        return ResponseEntity.ok(ApiResponse.success("로그아웃되었습니다.", null));
    }

    /**
     * 회원탈퇴
     * DELETE /api/v1/auth/withdraw
     */
    @DeleteMapping("/withdraw")
    public ResponseEntity<ApiResponse<Void>> withdraw() {
        Long memberId = SecurityUtil.getCurrentMemberId();
        authService.withdraw(memberId);
        return ResponseEntity.ok(ApiResponse.success("회원탈퇴가 완료되었습니다.", null));
    }
}
