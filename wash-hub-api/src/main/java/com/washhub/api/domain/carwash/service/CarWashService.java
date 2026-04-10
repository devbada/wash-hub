package com.washhub.api.domain.carwash.service;

import com.washhub.api.domain.carwash.dto.*;
import com.washhub.api.domain.carwash.entity.*;
import com.washhub.api.domain.carwash.repository.CarWashRepository;
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
import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

@Slf4j
@RequiredArgsConstructor
@Transactional(readOnly = true)
@Service
public class CarWashService {

    private final CarWashRepository carWashRepository;
    private final MemberRepository memberRepository;

    /**
     * 세차장 목록 조회 (카테고리 필터, 페이징)
     */
    public PageResponse<CarWashListResponse> getCarWashList(String category, Pageable pageable) {
        CarWashCategory carWashCategory = parseCategory(category);

        Page<CarWashListResponse> page = carWashRepository
                .findAllByStatusAndCategory(CarWashStatus.ACTIVE, carWashCategory, pageable)
                .map(CarWashListResponse::from);

        return PageResponse.from(page);
    }

    /**
     * 세차장 상세 조회 (편의시설 포함)
     */
    public CarWashResponse getCarWash(Long carWashId) {
        CarWash persistCarWash = carWashRepository
                .findByIdAndStatusWithFacilities(carWashId, CarWashStatus.ACTIVE)
                .orElseThrow(() -> new NotAcceptableException(ErrorCode.NOT_FOUND, "존재하지 않는 세차장입니다.")); // TODO-minam

        return CarWashResponse.from(persistCarWash);
    }

    /**
     * 세차장 등록
     */
    @Transactional
    public CarWashResponse createCarWash(CarWashCreateRequest request) {
        Long currentMemberId = SecurityUtil.getCurrentMemberId();

        Member persistMember = memberRepository.findById(currentMemberId)
                .orElseThrow(() -> new NotAcceptableException(ErrorCode.NOT_FOUND, "존재하지 않는 회원입니다.")); // TODO-minam

        CarWashCategory category = parseAndValidateCategory(request.getCategory());

        CarWash carWash = CarWash.builder()
                .member(persistMember)
                .name(request.getName())
                .category(category)
                .address(request.getAddress())
                .latitude(request.getLatitude())
                .longitude(request.getLongitude())
                .phone(request.getPhone())
                .operatingHours(request.getOperatingHours())
                .priceRange(request.getPriceRange())
                .imageUrl(request.getImageUrl())
                .build();

        // 편의시설 추가
        addFacilities(carWash, request.getFacilities());

        CarWash persistCarWash = carWashRepository.save(carWash);
        log.info("세차장 등록 완료: carWashId={}, memberId={}", persistCarWash.getId(), currentMemberId);

        return CarWashResponse.from(persistCarWash);
    }

    /**
     * 세차장 수정
     */
    @Transactional
    public CarWashResponse updateCarWash(Long carWashId, CarWashUpdateRequest request) {
        Long currentMemberId = SecurityUtil.getCurrentMemberId();

        CarWash persistCarWash = carWashRepository
                .findByIdAndStatusWithFacilities(carWashId, CarWashStatus.ACTIVE)
                .orElseThrow(() -> new NotAcceptableException(ErrorCode.NOT_FOUND, "존재하지 않는 세차장입니다.")); // TODO-minam

        if (!persistCarWash.isOwnedBy(currentMemberId)) {
            throw new NotAcceptableException(ErrorCode.FORBIDDEN, "본인이 등록한 세차장만 수정할 수 있습니다."); // TODO-minam
        }

        CarWashCategory category = parseAndValidateCategory(request.getCategory());
        persistCarWash.update(request.getName(), category, request.getAddress(),
                request.getLatitude(), request.getLongitude(),
                request.getPhone(), request.getOperatingHours(),
                request.getPriceRange(), request.getImageUrl());

        // 편의시설 갱신
        persistCarWash.clearFacilities();
        addFacilities(persistCarWash, request.getFacilities());

        log.info("세차장 수정 완료: carWashId={}, memberId={}", carWashId, currentMemberId);
        return CarWashResponse.from(persistCarWash);
    }

    /**
     * 세차장 삭제 (소프트 삭제)
     */
    @Transactional
    public void deleteCarWash(Long carWashId) {
        Long currentMemberId = SecurityUtil.getCurrentMemberId();

        CarWash persistCarWash = carWashRepository
                .findByIdAndStatusWithFacilities(carWashId, CarWashStatus.ACTIVE)
                .orElseThrow(() -> new NotAcceptableException(ErrorCode.NOT_FOUND, "존재하지 않는 세차장입니다.")); // TODO-minam

        if (!persistCarWash.isOwnedBy(currentMemberId)) {
            throw new NotAcceptableException(ErrorCode.FORBIDDEN, "본인이 등록한 세차장만 삭제할 수 있습니다."); // TODO-minam
        }

        persistCarWash.softDelete();
        log.info("세차장 삭제 완료: carWashId={}, memberId={}", carWashId, currentMemberId);
    }

    /**
     * 세차장 검색 (이름 기반)
     */
    public PageResponse<CarWashListResponse> searchCarWash(String keyword, Pageable pageable) {
        if (keyword == null || keyword.trim().isEmpty()) {
            throw new NotAcceptableException("검색어를 입력해주세요."); // TODO-minam
        }

        Page<CarWashListResponse> page = carWashRepository
                .searchByName(CarWashStatus.ACTIVE, keyword.trim(), pageable)
                .map(CarWashListResponse::from);

        return PageResponse.from(page);
    }

    /**
     * 편의시설 문자열 리스트를 Entity로 변환하여 추가
     */
    private void addFacilities(CarWash carWash, List<String> facilityTypes) {
        Optional.ofNullable(facilityTypes)
                .ifPresent(types -> types.stream()
                        .map(this::parseAndValidateFacilityType)
                        .map(type -> CarWashFacility.builder()
                                .carWash(carWash)
                                .facilityType(type)
                                .build())
                        .forEach(carWash::addFacility));
    }

    private CarWashCategory parseCategory(String category) {
        return Optional.ofNullable(category)
                .filter(c -> !c.isEmpty())
                .map(c -> {
                    try {
                        return CarWashCategory.valueOf(c.toUpperCase());
                    } catch (IllegalArgumentException e) {
                        return null;
                    }
                })
                .orElse(null);
    }

    private CarWashCategory parseAndValidateCategory(String category) {
        try {
            return CarWashCategory.valueOf(category.toUpperCase());
        } catch (IllegalArgumentException e) {
            throw new NotAcceptableException("유효하지 않은 세차장 유형입니다. 가능한 값: " +
                    Arrays.toString(CarWashCategory.values())); // TODO-minam
        }
    }

    private FacilityType parseAndValidateFacilityType(String facilityType) {
        try {
            return FacilityType.valueOf(facilityType.toUpperCase());
        } catch (IllegalArgumentException e) {
            throw new NotAcceptableException("유효하지 않은 편의시설 유형입니다. 가능한 값: " +
                    Arrays.toString(FacilityType.values())); // TODO-minam
        }
    }
}
