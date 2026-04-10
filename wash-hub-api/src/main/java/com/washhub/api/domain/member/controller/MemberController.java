package com.washhub.api.domain.member.controller;

import com.washhub.api.domain.member.dto.MemberResponse;
import com.washhub.api.domain.member.dto.MemberUpdateRequest;
import com.washhub.api.domain.member.service.MemberService;
import com.washhub.api.global.common.dto.ApiResponse;
import com.washhub.api.global.security.SecurityUtil;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import javax.validation.Valid;
import java.util.Collections;
import java.util.Map;

@RequiredArgsConstructor
@RestController
@RequestMapping("/api/v1/members")
public class MemberController {

    private final MemberService memberService;

    /**
     * 내 정보 조회
     * GET /api/v1/members/me
     */
    @GetMapping("/me")
    public ResponseEntity<ApiResponse<MemberResponse>> getMyInfo() {
        Long memberId = SecurityUtil.getCurrentMemberId();
        MemberResponse response = memberService.getMyInfo(memberId);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    /**
     * 내 정보 수정
     * PUT /api/v1/members/me
     */
    @PutMapping("/me")
    public ResponseEntity<ApiResponse<MemberResponse>> updateMyInfo(
            @Valid @RequestBody MemberUpdateRequest request) {
        Long memberId = SecurityUtil.getCurrentMemberId();
        MemberResponse response = memberService.updateMyInfo(memberId, request);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    /**
     * 닉네임 중복 확인
     * GET /api/v1/members/check-nickname?nickname=
     */
    @GetMapping("/check-nickname")
    public ResponseEntity<ApiResponse<Map<String, Boolean>>> checkNickname(
            @RequestParam String nickname) {
        boolean isDuplicate = memberService.checkNicknameDuplicate(nickname);
        return ResponseEntity.ok(
                ApiResponse.success(Collections.singletonMap("isDuplicate", isDuplicate))
        );
    }
}
