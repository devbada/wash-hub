package com.washhub.api.domain.feed.repository;

import com.washhub.api.domain.feed.entity.Feed;
import com.washhub.api.domain.feed.entity.FeedStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface FeedRepository extends JpaRepository<Feed, Long> {

    Page<Feed> findByStatus(FeedStatus status, Pageable pageable);

    @Query("SELECT f FROM Feed f WHERE f.member.id = :memberId AND f.status = :status")
    Page<Feed> findByMemberIdAndStatus(@Param("memberId") Long memberId,
                                        @Param("status") FeedStatus status,
                                        Pageable pageable);
}
