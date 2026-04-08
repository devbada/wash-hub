package com.washhub.api.domain.feed.repository;

import com.washhub.api.domain.feed.entity.FeedImage;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface FeedImageRepository extends JpaRepository<FeedImage, Long> {

    List<FeedImage> findByFeedIdOrderBySortOrder(Long feedId);

    void deleteAllByFeedId(Long feedId);
}
