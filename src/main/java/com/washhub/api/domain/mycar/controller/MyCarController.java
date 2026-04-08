package com.washhub.api.domain.mycar.controller;

import com.washhub.api.domain.mycar.dto.MyCarCreateRequest;
import com.washhub.api.domain.mycar.dto.MyCarResponse;
import com.washhub.api.domain.mycar.dto.MyCarUpdateRequest;
import com.washhub.api.domain.mycar.service.MyCarService;
import com.washhub.api.global.common.dto.ApiResponse;
import com.washhub.api.global.security.SecurityUtil;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import javax.validation.Valid;
import java.util.List;

@RequiredArgsConstructor
@RestController
@RequestMapping("/api/v1/my-cars")
public class MyCarController {

    private final MyCarService myCarService;

    /**
     * 내 차량 목록
     * GET /api/v1/my-cars
     */
    @GetMapping
    public ResponseEntity<ApiResponse<List<MyCarResponse>>> getMyCars() {
        Long memberId = SecurityUtil.getCurrentMemberId();
        List<MyCarResponse> response = myCarService.getMyCars(memberId);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    /**
     * 차량 등록
     * POST /api/v1/my-cars
     */
    @PostMapping
    public ResponseEntity<ApiResponse<MyCarResponse>> createMyCar(
            @Valid @RequestBody MyCarCreateRequest request) {
        Long memberId = SecurityUtil.getCurrentMemberId();
        MyCarResponse response = myCarService.createMyCar(memberId, request);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.success(response));
    }

    /**
     * 차량 수정
     * PUT /api/v1/my-cars/{myCarId}
     */
    @PutMapping("/{myCarId}")
    public ResponseEntity<ApiResponse<MyCarResponse>> updateMyCar(
            @PathVariable Long myCarId,
            @Valid @RequestBody MyCarUpdateRequest request) {
        Long memberId = SecurityUtil.getCurrentMemberId();
        MyCarResponse response = myCarService.updateMyCar(myCarId, memberId, request);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    /**
     * 차량 삭제
     * DELETE /api/v1/my-cars/{myCarId}
     */
    @DeleteMapping("/{myCarId}")
    public ResponseEntity<ApiResponse<Void>> deleteMyCar(@PathVariable Long myCarId) {
        Long memberId = SecurityUtil.getCurrentMemberId();
        myCarService.deleteMyCar(myCarId, memberId);
        return ResponseEntity.ok(ApiResponse.success("차량이 삭제되었습니다.", null));
    }
}
