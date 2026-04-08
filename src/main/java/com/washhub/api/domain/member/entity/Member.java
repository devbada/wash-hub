package com.washhub.api.domain.member.entity;

import com.washhub.api.global.common.entity.BaseEntity;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import javax.persistence.*;

@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@Table(name = "tb_member")
@Entity
public class Member extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "member_id")
    private Long id;

    @Column(name = "nickname", length = 30, unique = true)
    private String nickname;

    @Column(name = "profile_image_url", length = 500)
    private String profileImageUrl;

    @Enumerated(EnumType.STRING)
    @Column(name = "role", nullable = false, length = 20)
    private MemberRole role;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    private MemberStatus status;

    @Builder
    private Member(String nickname, String profileImageUrl) {
        this.nickname = nickname;
        this.profileImageUrl = profileImageUrl;
        this.role = MemberRole.USER;
        this.status = MemberStatus.ACTIVE;
    }

    /**
     * 프로필 정보 수정
     */
    public void updateProfile(String nickname, String profileImageUrl) {
        this.nickname = nickname;
        this.profileImageUrl = profileImageUrl;
    }

    /**
     * 회원 탈퇴 처리
     */
    public void withdraw() {
        this.status = MemberStatus.WITHDRAWN;
        this.nickname = null;
        this.profileImageUrl = null;
    }

    /**
     * 활성 회원 여부 확인
     */
    public boolean isActive() {
        return this.status == MemberStatus.ACTIVE;
    }
}
