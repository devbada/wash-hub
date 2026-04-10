package com.washhub.api.domain.feed.repository;

import com.washhub.api.domain.feed.entity.FeedLike;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface FeedLikeRepository extends JpaRepository<FeedLike, Long> {

    Optional<FeedLike> findByFeedIdAndMemberId(Long feedId, Long memberId);

    boolean existsByFeedIdAndMemberId(Long feedId, Long memberId);
}
