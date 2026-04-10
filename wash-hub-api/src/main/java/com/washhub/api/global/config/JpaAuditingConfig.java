package com.washhub.api.global.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.data.jpa.repository.config.EnableJpaAuditing;

/**
 * JPA Auditing 설정
 * - BaseEntity의 createdAt, updatedAt 자동 관리
 * - 테스트 시 @EnableJpaAuditing 충돌 방지를 위해 별도 Config 분리
 */
@Configuration
@EnableJpaAuditing
public class JpaAuditingConfig {
}
