package com.washhub.api.domain.carwash.entity;

import lombok.Getter;
import lombok.RequiredArgsConstructor;

@Getter
@RequiredArgsConstructor
public enum CarWashCategory {

    SELF("셀프세차장"),
    AUTO("자동세차장"),
    HAND("손세차장"),
    DETAIL("디테일링샵");

    private final String description;
}
