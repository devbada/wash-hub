package com.washhub.api.domain.feed.service;

import com.washhub.api.domain.feed.dto.*;
import com.washhub.api.domain.feed.entity.*;
import com.washhub.api.domain.feed.repository.*;
import com.washhub.api.domain.file.service.ImageCompositeService;
import com.washhub.api.domain.member.entity.Member;
import com.washhub.api.domain.member.repository.MemberRepository;
import com.washhub.api.global.common.dto.PageResponse;
import com.washhub.api.global.error.exception.ErrorCode;
import com.washhub.api.global.error.exception.NotAcceptableException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.stream.Collectors;

@Slf4j
@RequiredArgsConstructor
@Service
public class FeedService {

    private final FeedRepository feedRepository;
    private final FeedImageRepository feedImageRepository;
    private final FeedLikeRepository feedLikeRepository;
    private final FeedEquipmentRepository feedEquipmentRepository;
    private final MemberRepository memberRepository;
    private final ImageCompositeService imageCompositeService;

    /**
     * 피드 작성
     */
    @Transactional
    public FeedResponse createFeed(Long memberId, FeedCreateRequest request) {
        Member persistMember = memberRepository.findById(memberId)
                .orElseThrow(() -> new NotAcceptableException(ErrorCode.NOT_FOUND, "회원을 찾을 수 없습니다.")); // TODO-minam

        // 피드 생성
        Feed persistFeed = Feed.builder()
                .member(persistMember)
                .content(request.getContent())
                .washLocation(request.getWashLocation())
                .build();
        persistFeed = feedRepository.save(persistFeed);

        // Before 이미지 저장
        AtomicInteger beforeOrder = new AtomicInteger(0);
        final Feed savedFeed = persistFeed;
        request.getBeforeImageUrls().forEach(url -> {
            FeedImage image = FeedImage.builder()
                    .feed(savedFeed)
                    .imageUrl(url)
                    .imageType(ImageType.BEFORE)
                    .sortOrder(beforeOrder.getAndIncrement())
                    .build();
            feedImageRepository.save(image);
            savedFeed.addImage(image);
        });

        // After 이미지 저장
        AtomicInteger afterOrder = new AtomicInteger(0);
        request.getAfterImageUrls().forEach(url -> {
            FeedImage image = FeedImage.builder()
                    .feed(savedFeed)
                    .imageUrl(url)
                    .imageType(ImageType.AFTER)
                    .sortOrder(afterOrder.getAndIncrement())
                    .build();
            feedImageRepository.save(image);
            savedFeed.addImage(image);
        });

        // 케미컬 태그 연결
        Optional.ofNullable(request.getEquipmentIds()).ifPresent(ids ->
                ids.forEach(equipmentId -> {
                    FeedEquipment equipment = FeedEquipment.builder()
                            .feed(savedFeed)
                            .equipmentId(equipmentId)
                            .build();
                    feedEquipmentRepository.save(equipment);
                    savedFeed.addEquipment(equipment);
                })
        );

        // Before|After 합성 썸네일 생성
        try {
            String thumbnailUrl = imageCompositeService.createComposite(
                    request.getBeforeImageUrls().get(0),
                    request.getAfterImageUrls().get(0),
                    "feeds/" + savedFeed.getId()
            );
            savedFeed.updateThumbnailUrl(thumbnailUrl);
        } catch (Exception e) {
            log.warn("합성 썸네일 생성 실패 (피드는 정상 저장됨): feedId={}, error={}", savedFeed.getId(), e.getMessage());
        }

        log.info("피드 작성 완료: feedId={}, memberId={}", savedFeed.getId(), memberId);
        return FeedResponse.from(savedFeed, false);
    }

    /**
     * 피드 목록 조회 (페이징)
     */
    @Transactional(readOnly = true)
    public PageResponse<FeedListResponse> getFeedList(Pageable pageable, Long currentMemberId) {
        Page<Feed> persistFeeds = feedRepository.findByStatus(FeedStatus.ACTIVE, pageable);

        Page<FeedListResponse> responsePage = persistFeeds.map(feed -> {
            boolean liked = currentMemberId != null
                    && feedLikeRepository.existsByFeedIdAndMemberId(feed.getId(), currentMemberId);
            return FeedListResponse.from(feed, liked);
        });

        return PageResponse.from(responsePage);
    }

    /**
     * 피드 상세 조회
     */
    @Transactional(readOnly = true)
    public FeedResponse getFeedDetail(Long feedId, Long currentMemberId) {
        Feed persistFeed = feedRepository.findById(feedId)
                .filter(Feed::isActive)
                .orElseThrow(() -> new NotAcceptableException(ErrorCode.NOT_FOUND, "피드를 찾을 수 없습니다.")); // TODO-minam

        boolean liked = currentMemberId != null
                && feedLikeRepository.existsByFeedIdAndMemberId(feedId, currentMemberId);

        return FeedResponse.from(persistFeed, liked);
    }

    /**
     * 피드 수정 (본인만 가능)
     */
    @Transactional
    public FeedResponse updateFeed(Long feedId, Long memberId, FeedUpdateRequest request) {
        Feed persistFeed = feedRepository.findById(feedId)
                .filter(Feed::isActive)
                .orElseThrow(() -> new NotAcceptableException(ErrorCode.NOT_FOUND, "피드를 찾을 수 없습니다.")); // TODO-minam

        if (!persistFeed.isOwnedBy(memberId)) {
            throw new NotAcceptableException(ErrorCode.FORBIDDEN, "본인의 피드만 수정할 수 있습니다."); // TODO-minam
        }

        persistFeed.updateContent(request.getContent(), request.getWashLocation());

        // 케미컬 태그 업데이트
        Optional.ofNullable(request.getEquipmentIds()).ifPresent(ids -> {
            feedEquipmentRepository.deleteAllByFeedId(feedId);
            persistFeed.getEquipments().clear();
            ids.forEach(equipmentId -> {
                FeedEquipment equipment = FeedEquipment.builder()
                        .feed(persistFeed)
                        .equipmentId(equipmentId)
                        .build();
                feedEquipmentRepository.save(equipment);
                persistFeed.addEquipment(equipment);
            });
        });

        log.info("피드 수정 완료: feedId={}", feedId);
        boolean liked = feedLikeRepository.existsByFeedIdAndMemberId(feedId, memberId);
        return FeedResponse.from(persistFeed, liked);
    }

    /**
     * 피드 삭제 (소프트 삭제, 본인만 가능)
     */
    @Transactional
    public void deleteFeed(Long feedId, Long memberId) {
        Feed persistFeed = feedRepository.findById(feedId)
                .filter(Feed::isActive)
                .orElseThrow(() -> new NotAcceptableException(ErrorCode.NOT_FOUND, "피드를 찾을 수 없습니다.")); // TODO-minam

        if (!persistFeed.isOwnedBy(memberId)) {
            throw new NotAcceptableException(ErrorCode.FORBIDDEN, "본인의 피드만 삭제할 수 있습니다."); // TODO-minam
        }

        persistFeed.softDelete();
        log.info("피드 삭제 완료: feedId={}", feedId);
    }

    /**
     * 좋아요 토글
     * - 좋아요가 있으면 취소, 없으면 추가
     */
    @Transactional
    public boolean toggleLike(Long feedId, Long memberId) {
        Feed persistFeed = feedRepository.findById(feedId)
                .filter(Feed::isActive)
                .orElseThrow(() -> new NotAcceptableException(ErrorCode.NOT_FOUND, "피드를 찾을 수 없습니다.")); // TODO-minam

        Member persistMember = memberRepository.findById(memberId)
                .orElseThrow(() -> new NotAcceptableException(ErrorCode.NOT_FOUND, "회원을 찾을 수 없습니다.")); // TODO-minam

        Optional<FeedLike> persistFeedLike = feedLikeRepository.findByFeedIdAndMemberId(feedId, memberId);

        if (persistFeedLike.isPresent()) {
            // 좋아요 취소
            feedLikeRepository.delete(persistFeedLike.get());
            persistFeed.decreaseLikeCount();
            log.info("좋아요 취소: feedId={}, memberId={}", feedId, memberId);
            return false;
        } else {
            // 좋아요 추가
            FeedLike feedLike = FeedLike.builder()
                    .feed(persistFeed)
                    .member(persistMember)
                    .build();
            feedLikeRepository.save(feedLike);
            persistFeed.increaseLikeCount();
            log.info("좋아요 추가: feedId={}, memberId={}", feedId, memberId);
            return true;
        }
    }
}
