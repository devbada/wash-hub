package com.washhub.api.domain.mycar.dto;

import com.washhub.api.domain.mycar.entity.MyCar;
import lombok.Builder;
import lombok.Getter;

import java.time.LocalDateTime;

@Getter
@Builder
public class MyCarResponse {

    private final Long myCarId;
    private final String carModel;
    private final String carColor;
    private final Integer carYear;
    private final String imageUrl;
    private final boolean isPrimary;
    private final LocalDateTime createdAt;

    public static MyCarResponse from(MyCar myCar) {
        return MyCarResponse.builder()
                .myCarId(myCar.getId())
                .carModel(myCar.getCarModel())
                .carColor(myCar.getCarColor())
                .carYear(myCar.getCarYear())
                .imageUrl(myCar.getImageUrl())
                .isPrimary(myCar.isPrimary())
                .createdAt(myCar.getCreatedAt())
                .build();
    }
}
