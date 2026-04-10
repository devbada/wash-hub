package com.washhub.api.domain.member.dto;

import com.washhub.api.domain.member.entity.Member;
import lombok.Builder;
import lombok.Getter;

@Getter
@Builder
public class MemberResponse {

    private final Long memberId;
    private final String nickname;
    private final String profileImageUrl;
    private final String role;
    private final String status;

    public static MemberResponse from(Member member) {
        return MemberResponse.builder()
                .memberId(member.getId())
                .nickname(member.getNickname())
                .profileImageUrl(member.getProfileImageUrl())
                .role(member.getRole().name())
                .status(member.getStatus().name())
                .build();
    }
}
