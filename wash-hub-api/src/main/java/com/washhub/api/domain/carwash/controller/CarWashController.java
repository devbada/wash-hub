package com.washhub.api.domain.carwash.controller;

import com.washhub.api.domain.carwash.dto.*;
import com.washhub.api.domain.carwash.service.CarWashService;
import com.washhub.api.global.common.dto.ApiResponse;
import com.washhub.api.global.common.dto.PageResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import javax.validation.Valid;

@RequiredArgsConstructor
@RequestMapping("/api/v1/car-washes")
@RestController
public class CarWashController {

    private final CarWashService carWashService;

    /**
     * 세차장 목록 조회 (카테고리 필터)
     * GET /api/v1/car-washes?category=SELF&page=0&size=20
     */
    @GetMapping
    public ApiResponse<PageResponse<CarWashListResponse>> getCarWashList(
            @RequestParam(required = false) String category,
            @PageableDefault(size = 20, sort = "createdAt", direction = Sort.Direction.DESC) Pageable pageable) {
        return ApiResponse.success(carWashService.getCarWashList(category, pageable));
    }

    /**
     * 세차장 상세 조회 (편의시설 포함)
     * GET /api/v1/car-washes/{carWashId}
     */
    @GetMapping("/{carWashId}")
    public ApiResponse<CarWashResponse> getCarWash(@PathVariable Long carWashId) {
        return ApiResponse.success(carWashService.getCarWash(carWashId));
    }

    /**
     * 세차장 등록
     * POST /api/v1/car-washes
     */
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<CarWashResponse> createCarWash(@Valid @RequestBody CarWashCreateRequest request) {
        return ApiResponse.success(carWashService.createCarWash(request));
    }

    /**
     * 세차장 수정
     * PUT /api/v1/car-washes/{carWashId}
     */
    @PutMapping("/{carWashId}")
    public ApiResponse<CarWashResponse> updateCarWash(
            @PathVariable Long carWashId,
            @Valid @RequestBody CarWashUpdateRequest request) {
        return ApiResponse.success(carWashService.updateCarWash(carWashId, request));
    }

    /**
     * 세차장 삭제
     * DELETE /api/v1/car-washes/{carWashId}
     */
    @DeleteMapping("/{carWashId}")
    public ApiResponse<Void> deleteCarWash(@PathVariable Long carWashId) {
        carWashService.deleteCarWash(carWashId);
        return ApiResponse.success();
    }

    /**
     * 세차장 검색
     * GET /api/v1/car-washes/search?keyword=셀프&page=0&size=20
     */
    @GetMapping("/search")
    public ApiResponse<PageResponse<CarWashListResponse>> searchCarWash(
            @RequestParam String keyword,
            @PageableDefault(size = 20, sort = "createdAt", direction = Sort.Direction.DESC) Pageable pageable) {
        return ApiResponse.success(carWashService.searchCarWash(keyword, pageable));
    }
}
