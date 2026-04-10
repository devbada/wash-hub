package com.washhub.api.domain.washlog.dto;

import lombok.AllArgsConstructor;
import lombok.Getter;

@Getter
@AllArgsConstructor
public class WashStatsResponse {

    private final int year;
    private final int month;
    private final long count;
}
