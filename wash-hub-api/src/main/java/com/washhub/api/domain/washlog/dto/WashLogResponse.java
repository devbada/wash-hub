package com.washhub.api.domain.washlog.dto;

import com.washhub.api.domain.washlog.entity.WashLog;
import lombok.Builder;
import lombok.Getter;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;

@Getter
@Builder
public class WashLogResponse {

    private final Long washLogId;
    private final Long myCarId;
    private final String carModel;
    private final Long feedId;
    private final Long carWashId;
    private final LocalDate washDate;
    private final String memo;
    private final List<Long> equipmentIds;
    private final LocalDateTime createdAt;

    public static WashLogResponse from(WashLog washLog) {
        List<Long> equipmentIds = washLog.getEquipments().stream()
                .map(eq -> eq.getEquipmentId())
                .collect(Collectors.toList());

        return WashLogResponse.builder()
                .washLogId(washLog.getId())
                .myCarId(washLog.getMyCar() != null ? washLog.getMyCar().getId() : null)
                .carModel(washLog.getMyCar() != null ? washLog.getMyCar().getCarModel() : null)
                .feedId(washLog.getFeedId())
                .carWashId(washLog.getCarWashId())
                .washDate(washLog.getWashDate())
                .memo(washLog.getMemo())
                .equipmentIds(equipmentIds)
                .createdAt(washLog.getCreatedAt())
                .build();
    }
}
