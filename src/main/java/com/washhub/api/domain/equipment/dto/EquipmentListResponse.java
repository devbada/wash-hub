package com.washhub.api.domain.equipment.dto;

import com.washhub.api.domain.equipment.entity.Equipment;
import lombok.Builder;
import lombok.Getter;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Getter
@Builder
public class EquipmentListResponse {

    private Long equipmentId;
    private String category;
    private String categoryName;
    private String name;
    private String brand;
    private String imageUrl;
    private BigDecimal avgRating;
    private int reviewCount;
    private String memberNickname;
    private LocalDateTime createdAt;

    public static EquipmentListResponse from(Equipment equipment) {
        return EquipmentListResponse.builder()
                .equipmentId(equipment.getId())
                .category(equipment.getCategory().name())
                .categoryName(equipment.getCategory().getDescription())
                .name(equipment.getName())
                .brand(equipment.getBrand())
                .imageUrl(equipment.getImageUrl())
                .avgRating(equipment.getAvgRating())
                .reviewCount(equipment.getReviewCount())
                .memberNickname(equipment.getMember().getNickname())
                .createdAt(equipment.getCreatedAt())
                .build();
    }
}
