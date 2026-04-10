package com.washhub.api.infra.kakao;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@NoArgsConstructor
@JsonIgnoreProperties(ignoreUnknown = true)
public class KakaoUserInfo {

    @JsonProperty("id")
    private Long id;

    @JsonProperty("kakao_account")
    private KakaoAccount kakaoAccount;

    @Getter
    @NoArgsConstructor
    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class KakaoAccount {

        @JsonProperty("profile")
        private Profile profile;

        @Getter
        @NoArgsConstructor
        @JsonIgnoreProperties(ignoreUnknown = true)
        public static class Profile {

            @JsonProperty("nickname")
            private String nickname;

            @JsonProperty("profile_image_url")
            private String profileImageUrl;
        }
    }

    /**
     * 카카오 고유 ID (문자열 변환)
     */
    public String getProviderId() {
        return String.valueOf(this.id);
    }

    /**
     * 카카오 프로필 닉네임
     */
    public String getNickname() {
        return (kakaoAccount != null && kakaoAccount.getProfile() != null)
                ? kakaoAccount.getProfile().getNickname()
                : null;
    }

    /**
     * 카카오 프로필 이미지 URL
     */
    public String getProfileImageUrl() {
        return (kakaoAccount != null && kakaoAccount.getProfile() != null)
                ? kakaoAccount.getProfile().getProfileImageUrl()
                : null;
    }
}
