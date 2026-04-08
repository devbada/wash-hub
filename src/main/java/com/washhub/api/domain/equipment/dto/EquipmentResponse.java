package com.washhub.api.domain.equipment.dto;

import com.washhub.api.domain.equipment.entity.Equipment;
import lombok.Builder;
import lombok.Getter;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Getter
@Builder
public class EquipmentResponse {

    private Long equipmentId;
    private String category;
    private String categoryName;
    private String name;
    private String brand;
    private String description;
    private String imageUrl;
    private BigDecimal avgRating;
    private int reviewCount;
    private Long memberId;
    private String memberNickname;
    private LocalDateTime createdAt;

    public static EquipmentResponse from(Equipment equipment) {
        return EquipmentResponse.builder()
                .equipmentId(equipment.getId())
                .category(equipment.getCategory().name())
                .categoryName(equipment.getCategory().getDescription())
                .name(equipment.getName())
                .brand(equipment.getBrand())
                .description(equipment.getDescription())
                .imageUrl(equipment.getImageUrl())
                .avgRating(equipment.getAvgRating())
                .reviewCount(equipment.getReviewCount())
                .memberId(equipment.getMember().getId())
                .memberNickname(equipment.getMember().getNickname())
                .createdAt(equipment.getCreatedAt())
                .build();
    }
}
