package com.washhub.api.domain.equipment.dto;

import lombok.Getter;
import lombok.NoArgsConstructor;

import javax.validation.constraints.NotBlank;
import javax.validation.constraints.NotNull;
import javax.validation.constraints.Size;

@Getter
@NoArgsConstructor
public class EquipmentUpdateRequest {

    @NotNull(message = "카테고리는 필수입니다")
    private String category;

    @NotBlank(message = "제품명은 필수입니다")
    @Size(max = 100, message = "제품명은 100자 이내여야 합니다")
    private String name;

    @Size(max = 100, message = "브랜드명은 100자 이내여야 합니다")
    private String brand;

    private String description;

    private String imageUrl;
}
