package com.washhub.api.domain.carwash.dto;

import com.washhub.api.domain.carwash.entity.CarWash;
import lombok.Builder;
import lombok.Getter;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Getter
@Builder
public class CarWashListResponse {

    private Long carWashId;
    private String category;
    private String categoryName;
    private String name;
    private String address;
    private String imageUrl;
    private BigDecimal avgRating;
    private int reviewCount;
    private String memberNickname;
    private LocalDateTime createdAt;

    public static CarWashListResponse from(CarWash carWash) {
        return CarWashListResponse.builder()
                .carWashId(carWash.getId())
                .category(carWash.getCategory().name())
                .categoryName(carWash.getCategory().getDescription())
                .name(carWash.getName())
                .address(carWash.getAddress())
                .imageUrl(carWash.getImageUrl())
                .avgRating(carWash.getAvgRating())
                .reviewCount(carWash.getReviewCount())
                .memberNickname(carWash.getMember().getNickname())
                .createdAt(carWash.getCreatedAt())
                .build();
    }
}
