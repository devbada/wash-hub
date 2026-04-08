package com.washhub.api.domain.carwash.dto;

import lombok.Getter;
import lombok.NoArgsConstructor;

import javax.validation.constraints.NotBlank;
import javax.validation.constraints.NotNull;
import javax.validation.constraints.Size;
import java.math.BigDecimal;
import java.util.List;

@Getter
@NoArgsConstructor
public class CarWashUpdateRequest {

    @NotBlank(message = "세차장명은 필수입니다")
    @Size(max = 100, message = "세차장명은 100자 이내여야 합니다")
    private String name;

    @NotNull(message = "세차장 유형은 필수입니다")
    private String category;

    @Size(max = 300, message = "주소는 300자 이내여야 합니다")
    private String address;

    private BigDecimal latitude;

    private BigDecimal longitude;

    @Size(max = 20, message = "전화번호는 20자 이내여야 합니다")
    private String phone;

    @Size(max = 100, message = "영업시간은 100자 이내여야 합니다")
    private String operatingHours;

    @Size(max = 50, message = "가격대는 50자 이내여야 합니다")
    private String priceRange;

    private String imageUrl;

    private List<String> facilities;
}
