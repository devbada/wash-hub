package com.washhub.api.domain.equipment.controller;

import com.washhub.api.domain.equipment.dto.*;
import com.washhub.api.domain.equipment.service.EquipmentService;
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
@RequestMapping("/api/v1/equipments")
@RestController
public class EquipmentController {

    private final EquipmentService equipmentService;

    /**
     * 케미컬/장비 목록 조회 (카테고리 필터)
     * GET /api/v1/equipments?category=CLEANSER&page=0&size=20
     */
    @GetMapping
    public ApiResponse<PageResponse<EquipmentListResponse>> getEquipmentList(
            @RequestParam(required = false) String category,
            @PageableDefault(size = 20, sort = "createdAt", direction = Sort.Direction.DESC) Pageable pageable) {
        return ApiResponse.success(equipmentService.getEquipmentList(category, pageable));
    }

    /**
     * 케미컬/장비 상세 조회
     * GET /api/v1/equipments/{equipmentId}
     */
    @GetMapping("/{equipmentId}")
    public ApiResponse<EquipmentResponse> getEquipment(@PathVariable Long equipmentId) {
        return ApiResponse.success(equipmentService.getEquipment(equipmentId));
    }

    /**
     * 케미컬/장비 등록
     * POST /api/v1/equipments
     */
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<EquipmentResponse> createEquipment(@Valid @RequestBody EquipmentCreateRequest request) {
        return ApiResponse.success(equipmentService.createEquipment(request));
    }

    /**
     * 케미컬/장비 수정
     * PUT /api/v1/equipments/{equipmentId}
     */
    @PutMapping("/{equipmentId}")
    public ApiResponse<EquipmentResponse> updateEquipment(
            @PathVariable Long equipmentId,
            @Valid @RequestBody EquipmentUpdateRequest request) {
        return ApiResponse.success(equipmentService.updateEquipment(equipmentId, request));
    }

    /**
     * 케미컬/장비 삭제
     * DELETE /api/v1/equipments/{equipmentId}
     */
    @DeleteMapping("/{equipmentId}")
    public ApiResponse<Void> deleteEquipment(@PathVariable Long equipmentId) {
        equipmentService.deleteEquipment(equipmentId);
        return ApiResponse.success();
    }

    /**
     * 케미컬/장비 검색
     * GET /api/v1/equipments/search?keyword=샴푸&page=0&size=20
     */
    @GetMapping("/search")
    public ApiResponse<PageResponse<EquipmentListResponse>> searchEquipment(
            @RequestParam String keyword,
            @PageableDefault(size = 20, sort = "createdAt", direction = Sort.Direction.DESC) Pageable pageable) {
        return ApiResponse.success(equipmentService.searchEquipment(keyword, pageable));
    }
}
