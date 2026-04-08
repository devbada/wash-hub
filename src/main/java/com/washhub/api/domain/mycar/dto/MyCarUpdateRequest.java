package com.washhub.api.domain.mycar.dto;

import lombok.Getter;
import lombok.NoArgsConstructor;

import javax.validation.constraints.NotBlank;
import javax.validation.constraints.Size;

@Getter
@NoArgsConstructor
public class MyCarUpdateRequest {

    @NotBlank(message = "차종은 필수입니다.")
    @Size(max = 100, message = "차종은 100자 이내로 입력해주세요.")
    private String carModel;

    private String carColor;
    private Integer carYear;
    private String imageUrl;
}
