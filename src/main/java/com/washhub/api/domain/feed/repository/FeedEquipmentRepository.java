package com.washhub.api.domain.feed.repository;

import com.washhub.api.domain.feed.entity.FeedEquipment;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface FeedEquipmentRepository extends JpaRepository<FeedEquipment, Long> {

    List<FeedEquipment> findByFeedId(Long feedId);

    void deleteAllByFeedId(Long feedId);
}
