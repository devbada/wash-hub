package com.washhub.api.domain.washlog.dto;

import com.fasterxml.jackson.annotation.JsonFormat;
import lombok.Getter;
import lombok.NoArgsConstructor;

import javax.validation.constraints.NotNull;
import java.time.LocalDate;
import java.util.List;

@Getter
@NoArgsConstructor
public class WashLogCreateRequest {

    private Long myCarId;
    private Long feedId;
    private Long carWashId;

    @NotNull(message = "세차 날짜는 필수입니다.")
    @JsonFormat(pattern = "yyyy-MM-dd")
    private LocalDate washDate;

    private String memo;
    private List<Long> equipmentIds;
}
