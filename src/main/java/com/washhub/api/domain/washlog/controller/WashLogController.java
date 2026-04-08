package com.washhub.api.domain.washlog.controller;

import com.washhub.api.domain.washlog.dto.WashLogCreateRequest;
import com.washhub.api.domain.washlog.dto.WashLogResponse;
import com.washhub.api.domain.washlog.dto.WashStatsResponse;
import com.washhub.api.domain.washlog.service.WashLogService;
import com.washhub.api.global.common.dto.ApiResponse;
import com.washhub.api.global.common.dto.PageResponse;
import com.washhub.api.global.security.SecurityUtil;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import javax.validation.Valid;
import java.util.List;

@RequiredArgsConstructor
@RestController
@RequestMapping("/api/v1/wash-logs")
public class WashLogController {

    private final WashLogService washLogService;

    /**
     * 세차 기록 목록 (페이징)
     * GET /api/v1/wash-logs
     */
    @GetMapping
    public ResponseEntity<ApiResponse<PageResponse<WashLogResponse>>> getWashLogs(
            @PageableDefault(size = 20, sort = "washDate", direction = Sort.Direction.DESC) Pageable pageable) {
        Long memberId = SecurityUtil.getCurrentMemberId();
        PageResponse<WashLogResponse> response = washLogService.getWashLogs(memberId, pageable);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    /**
     * 세차 기록 추가
     * POST /api/v1/wash-logs
     */
    @PostMapping
    public ResponseEntity<ApiResponse<WashLogResponse>> createWashLog(
            @Valid @RequestBody WashLogCreateRequest request) {
        Long memberId = SecurityUtil.getCurrentMemberId();
        WashLogResponse response = washLogService.createWashLog(memberId, request);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.success(response));
    }

    /**
     * 세차 기록 상세
     * GET /api/v1/wash-logs/{washLogId}
     */
    @GetMapping("/{washLogId}")
    public ResponseEntity<ApiResponse<WashLogResponse>> getWashLogDetail(@PathVariable Long washLogId) {
        Long memberId = SecurityUtil.getCurrentMemberId();
        WashLogResponse response = washLogService.getWashLogDetail(washLogId, memberId);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    /**
     * 세차 기록 삭제
     * DELETE /api/v1/wash-logs/{washLogId}
     */
    @DeleteMapping("/{washLogId}")
    public ResponseEntity<ApiResponse<Void>> deleteWashLog(@PathVariable Long washLogId) {
        Long memberId = SecurityUtil.getCurrentMemberId();
        washLogService.deleteWashLog(washLogId, memberId);
        return ResponseEntity.ok(ApiResponse.success("세차 기록이 삭제되었습니다.", null));
    }

    /**
     * 월별 세차 횟수 통계
     * GET /api/v1/wash-logs/stats
     */
    @GetMapping("/stats")
    public ResponseEntity<ApiResponse<List<WashStatsResponse>>> getMonthlyStats() {
        Long memberId = SecurityUtil.getCurrentMemberId();
        List<WashStatsResponse> response = washLogService.getMonthlyStats(memberId);
        return ResponseEntity.ok(ApiResponse.success(response));
    }
}
