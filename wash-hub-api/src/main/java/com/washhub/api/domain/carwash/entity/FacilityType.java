package com.washhub.api.domain.carwash.entity;

import lombok.Getter;
import lombok.RequiredArgsConstructor;

@Getter
@RequiredArgsConstructor
public enum FacilityType {

    HIGH_PRESSURE("고압수"),
    AIR_GUN("에어건"),
    MAT_WASHER("매트세척기"),
    VACUUM("실내청소기"),
    PARKING("주차 편의"),
    OPEN_24H("24시간 운영");

    private final String description;
}
