package com.washhub.api.domain.equipment.service;

import com.washhub.api.domain.equipment.dto.*;
import com.washhub.api.domain.equipment.entity.Equipment;
import com.washhub.api.domain.equipment.entity.EquipmentCategory;
import com.washhub.api.domain.equipment.entity.EquipmentStatus;
import com.washhub.api.domain.equipment.repository.EquipmentRepository;
import com.washhub.api.domain.member.entity.Member;
import com.washhub.api.domain.member.repository.MemberRepository;
import com.washhub.api.global.common.dto.PageResponse;
import com.washhub.api.global.error.exception.ErrorCode;
import com.washhub.api.global.error.exception.NotAcceptableException;
import com.washhub.api.global.security.SecurityUtil;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Arrays;
import java.util.Optional;

@Slf4j
@RequiredArgsConstructor
@Transactional(readOnly = true)
@Service
public class EquipmentService {

    private final EquipmentRepository equipmentRepository;
    private final MemberRepository memberRepository;

    /**
     * 케미컬/장비 목록 조회 (카테고리 필터, 페이징)
     */
    public PageResponse<EquipmentListResponse> getEquipmentList(String category, Pageable pageable) {
        EquipmentCategory equipmentCategory = parseCategory(category);

        Page<EquipmentListResponse> page = equipmentRepository
                .findAllByStatusAndCategory(EquipmentStatus.ACTIVE, equipmentCategory, pageable)
                .map(EquipmentListResponse::from);

        return PageResponse.from(page);
    }

    /**
     * 케미컬/장비 상세 조회
     */
    public EquipmentResponse getEquipment(Long equipmentId) {
        Equipment persistEquipment = equipmentRepository
                .findByIdAndStatus(equipmentId, EquipmentStatus.ACTIVE)
                .orElseThrow(() -> new NotAcceptableException(ErrorCode.NOT_FOUND, "존재하지 않는 장비/케미컬입니다.")); // TODO-minam

        return EquipmentResponse.from(persistEquipment);
    }

    /**
     * 케미컬/장비 등록
     */
    @Transactional
    public EquipmentResponse createEquipment(EquipmentCreateRequest request) {
        Long currentMemberId = SecurityUtil.getCurrentMemberId();

        Member persistMember = memberRepository.findById(currentMemberId)
                .orElseThrow(() -> new NotAcceptableException(ErrorCode.NOT_FOUND, "존재하지 않는 회원입니다.")); // TODO-minam

        EquipmentCategory category = parseAndValidateCategory(request.getCategory());

        Equipment equipment = Equipment.builder()
                .member(persistMember)
                .category(category)
                .name(request.getName())
                .brand(request.getBrand())
                .description(request.getDescription())
                .imageUrl(request.getImageUrl())
                .build();

        Equipment persistEquipment = equipmentRepository.save(equipment);
        log.info("케미컬/장비 등록 완료: equipmentId={}, memberId={}", persistEquipment.getId(), currentMemberId);

        return EquipmentResponse.from(persistEquipment);
    }

    /**
     * 케미컬/장비 수정
     */
    @Transactional
    public EquipmentResponse updateEquipment(Long equipmentId, EquipmentUpdateRequest request) {
        Long currentMemberId = SecurityUtil.getCurrentMemberId();

        Equipment persistEquipment = equipmentRepository
                .findByIdAndStatus(equipmentId, EquipmentStatus.ACTIVE)
                .orElseThrow(() -> new NotAcceptableException(ErrorCode.NOT_FOUND, "존재하지 않는 장비/케미컬입니다.")); // TODO-minam

        if (!persistEquipment.isOwnedBy(currentMemberId)) {
            throw new NotAcceptableException(ErrorCode.FORBIDDEN, "본인이 등록한 장비/케미컬만 수정할 수 있습니다."); // TODO-minam
        }

        EquipmentCategory category = parseAndValidateCategory(request.getCategory());
        persistEquipment.update(request.getName(), request.getBrand(),
                request.getDescription(), category, request.getImageUrl());

        log.info("케미컬/장비 수정 완료: equipmentId={}, memberId={}", equipmentId, currentMemberId);
        return EquipmentResponse.from(persistEquipment);
    }

    /**
     * 케미컬/장비 삭제 (소프트 삭제)
     */
    @Transactional
    public void deleteEquipment(Long equipmentId) {
        Long currentMemberId = SecurityUtil.getCurrentMemberId();

        Equipment persistEquipment = equipmentRepository
                .findByIdAndStatus(equipmentId, EquipmentStatus.ACTIVE)
                .orElseThrow(() -> new NotAcceptableException(ErrorCode.NOT_FOUND, "존재하지 않는 장비/케미컬입니다.")); // TODO-minam

        if (!persistEquipment.isOwnedBy(currentMemberId)) {
            throw new NotAcceptableException(ErrorCode.FORBIDDEN, "본인이 등록한 장비/케미컬만 삭제할 수 있습니다."); // TODO-minam
        }

        persistEquipment.softDelete();
        log.info("케미컬/장비 삭제 완료: equipmentId={}, memberId={}", equipmentId, currentMemberId);
    }

    /**
     * 케미컬/장비 검색 (이름 기반)
     */
    public PageResponse<EquipmentListResponse> searchEquipment(String keyword, Pageable pageable) {
        if (keyword == null || keyword.trim().isEmpty()) {
            throw new NotAcceptableException("검색어를 입력해주세요."); // TODO-minam
        }

        Page<EquipmentListResponse> page = equipmentRepository
                .searchByName(EquipmentStatus.ACTIVE, keyword.trim(), pageable)
                .map(EquipmentListResponse::from);

        return PageResponse.from(page);
    }

    /**
     * 카테고리 문자열을 Enum으로 변환 (null이면 전체 조회)
     */
    private EquipmentCategory parseCategory(String category) {
        return Optional.ofNullable(category)
                .filter(c -> !c.isEmpty())
                .map(c -> {
                    try {
                        return EquipmentCategory.valueOf(c.toUpperCase());
                    } catch (IllegalArgumentException e) {
                        return null;
                    }
                })
                .orElse(null);
    }

    /**
     * 카테고리 문자열 유효성 검증 포함 변환
     */
    private EquipmentCategory parseAndValidateCategory(String category) {
        try {
            return EquipmentCategory.valueOf(category.toUpperCase());
        } catch (IllegalArgumentException e) {
            throw new NotAcceptableException("유효하지 않은 카테고리입니다. 가능한 값: " +
                    Arrays.toString(EquipmentCategory.values())); // TODO-minam
        }
    }
}
