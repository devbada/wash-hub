package com.washhub.api.domain.carwash.dto;

import com.washhub.api.domain.carwash.entity.CarWash;
import com.washhub.api.domain.carwash.entity.CarWashFacility;
import lombok.Builder;
import lombok.Getter;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;

@Getter
@Builder
public class CarWashResponse {

    private Long carWashId;
    private String category;
    private String categoryName;
    private String name;
    private String address;
    private BigDecimal latitude;
    private BigDecimal longitude;
    private String phone;
    private String operatingHours;
    private String priceRange;
    private String imageUrl;
    private BigDecimal avgRating;
    private int reviewCount;
    private List<FacilityDto> facilities;
    private Long memberId;
    private String memberNickname;
    private LocalDateTime createdAt;

    public static CarWashResponse from(CarWash carWash) {
        List<FacilityDto> facilityDtos = carWash.getFacilities().stream()
                .map(FacilityDto::from)
                .collect(Collectors.toList());

        return CarWashResponse.builder()
                .carWashId(carWash.getId())
                .category(carWash.getCategory().name())
                .categoryName(carWash.getCategory().getDescription())
                .name(carWash.getName())
                .address(carWash.getAddress())
                .latitude(carWash.getLatitude())
                .longitude(carWash.getLongitude())
                .phone(carWash.getPhone())
                .operatingHours(carWash.getOperatingHours())
                .priceRange(carWash.getPriceRange())
                .imageUrl(carWash.getImageUrl())
                .avgRating(carWash.getAvgRating())
                .reviewCount(carWash.getReviewCount())
                .facilities(facilityDtos)
                .memberId(carWash.getMember().getId())
                .memberNickname(carWash.getMember().getNickname())
                .createdAt(carWash.getCreatedAt())
                .build();
    }

    @Getter
    @Builder
    public static class FacilityDto {
        private String type;
        private String typeName;

        public static FacilityDto from(CarWashFacility facility) {
            return FacilityDto.builder()
                    .type(facility.getFacilityType().name())
                    .typeName(facility.getFacilityType().getDescription())
                    .build();
        }
    }
}
