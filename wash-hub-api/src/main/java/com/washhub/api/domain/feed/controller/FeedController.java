package com.washhub.api.domain.feed.controller;

import com.washhub.api.domain.feed.dto.FeedCreateRequest;
import com.washhub.api.domain.feed.dto.FeedListResponse;
import com.washhub.api.domain.feed.dto.FeedResponse;
import com.washhub.api.domain.feed.dto.FeedUpdateRequest;
import com.washhub.api.domain.feed.service.FeedService;
import com.washhub.api.global.common.dto.ApiResponse;
import com.washhub.api.global.common.dto.PageResponse;
import com.washhub.api.global.security.SecurityUtil;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import javax.validation.Valid;
import java.util.Collections;
import java.util.Map;
import java.util.Optional;

@RequiredArgsConstructor
@RestController
@RequestMapping("/api/v1/feeds")
public class FeedController {

    private final FeedService feedService;

    /**
     * 피드 작성
     * POST /api/v1/feeds
     */
    @PostMapping
    public ResponseEntity<ApiResponse<FeedResponse>> createFeed(
            @Valid @RequestBody FeedCreateRequest request) {
        Long memberId = SecurityUtil.getCurrentMemberId();
        FeedResponse response = feedService.createFeed(memberId, request);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.success(response));
    }

    /**
     * 피드 목록 (페이징)
     * GET /api/v1/feeds?page=0&size=20&sort=createdAt,desc
     */
    @GetMapping
    public ResponseEntity<ApiResponse<PageResponse<FeedListResponse>>> getFeedList(
            @PageableDefault(size = 20, sort = "createdAt", direction = Sort.Direction.DESC) Pageable pageable) {
        Long currentMemberId = getCurrentMemberIdOrNull();
        PageResponse<FeedListResponse> response = feedService.getFeedList(pageable, currentMemberId);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    /**
     * 피드 상세
     * GET /api/v1/feeds/{feedId}
     */
    @GetMapping("/{feedId}")
    public ResponseEntity<ApiResponse<FeedResponse>> getFeedDetail(@PathVariable Long feedId) {
        Long currentMemberId = getCurrentMemberIdOrNull();
        FeedResponse response = feedService.getFeedDetail(feedId, currentMemberId);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    /**
     * 피드 수정
     * PUT /api/v1/feeds/{feedId}
     */
    @PutMapping("/{feedId}")
    public ResponseEntity<ApiResponse<FeedResponse>> updateFeed(
            @PathVariable Long feedId,
            @Valid @RequestBody FeedUpdateRequest request) {
        Long memberId = SecurityUtil.getCurrentMemberId();
        FeedResponse response = feedService.updateFeed(feedId, memberId, request);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    /**
     * 피드 삭제
     * DELETE /api/v1/feeds/{feedId}
     */
    @DeleteMapping("/{feedId}")
    public ResponseEntity<ApiResponse<Void>> deleteFeed(@PathVariable Long feedId) {
        Long memberId = SecurityUtil.getCurrentMemberId();
        feedService.deleteFeed(feedId, memberId);
        return ResponseEntity.ok(ApiResponse.success("피드가 삭제되었습니다.", null));
    }

    /**
     * 좋아요 토글
     * POST /api/v1/feeds/{feedId}/like
     */
    @PostMapping("/{feedId}/like")
    public ResponseEntity<ApiResponse<Map<String, Boolean>>> toggleLike(@PathVariable Long feedId) {
        Long memberId = SecurityUtil.getCurrentMemberId();
        boolean liked = feedService.toggleLike(feedId, memberId);
        return ResponseEntity.ok(ApiResponse.success(Collections.singletonMap("liked", liked)));
    }

    /**
     * 현재 로그인한 회원 ID (비로그인 시 null)
     * - 피드 목록/상세는 비로그인도 접근 가능하므로 null 허용
     */
    private Long getCurrentMemberIdOrNull() {
        return Optional.ofNullable(SecurityContextHolder.getContext().getAuthentication())
                .map(Authentication::getPrincipal)
                .filter(principal -> principal instanceof Long)
                .map(principal -> (Long) principal)
                .orElse(null);
    }
}
