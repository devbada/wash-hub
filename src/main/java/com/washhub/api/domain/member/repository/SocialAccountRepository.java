package com.washhub.api.domain.member.repository;

import com.washhub.api.domain.member.entity.SocialAccount;
import com.washhub.api.domain.member.entity.SocialProvider;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface SocialAccountRepository extends JpaRepository<SocialAccount, Long> {

    Optional<SocialAccount> findByProviderAndProviderId(SocialProvider provider, String providerId);

    void deleteAllByMemberId(Long memberId);
}
