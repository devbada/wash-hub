package com.washhub.api.domain.auth.dto;

import lombok.Getter;
import lombok.NoArgsConstructor;

import javax.validation.constraints.NotBlank;

@Getter
@NoArgsConstructor
public class RefreshRequest {

    @NotBlank(message = "Refresh token은 필수입니다.")
    private String refreshToken;
}
