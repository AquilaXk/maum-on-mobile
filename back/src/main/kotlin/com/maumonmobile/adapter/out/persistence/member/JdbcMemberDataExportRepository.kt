package com.maumonmobile.adapter.out.persistence.member

import com.maumonmobile.adapter.out.persistence.jdbc.insertAndReturnId
import com.maumonmobile.adapter.out.persistence.jdbc.params
import com.maumonmobile.adapter.out.persistence.jdbc.withValue
import com.maumonmobile.application.port.out.MemberDataExportRepository
import com.maumonmobile.domain.member.MemberDataExportJob
import com.maumonmobile.domain.member.MemberDataExportStatus
import org.springframework.context.annotation.Profile
import org.springframework.jdbc.core.RowMapper
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate
import org.springframework.stereotype.Repository

@Repository
@Profile("!memory")
class JdbcMemberDataExportRepository(
    private val jdbc: NamedParameterJdbcTemplate,
) : MemberDataExportRepository {

    override fun save(job: MemberDataExportJob): MemberDataExportJob {
        if (job.id == 0L) {
            val id = jdbc.insertAndReturnId(
                """
                    insert into member_data_exports (
                        member_id,
                        status,
                        requested_at,
                        completed_at,
                        expires_at,
                        downloaded_at,
                        failure_reason,
                        content_json
                    ) values (
                        :memberId,
                        :status,
                        :requestedAt,
                        :completedAt,
                        :expiresAt,
                        :downloadedAt,
                        :failureReason,
                        :contentJson
                    )
                """.trimIndent(),
                job.toParams(),
            )
            return job.copy(id = id)
        }

        jdbc.update(
            """
                update member_data_exports
                   set member_id = :memberId,
                       status = :status,
                       requested_at = :requestedAt,
                       completed_at = :completedAt,
                       expires_at = :expiresAt,
                       downloaded_at = :downloadedAt,
                       failure_reason = :failureReason,
                       content_json = :contentJson
                 where id = :id
            """.trimIndent(),
            job.toParams().withValue("id", job.id),
        )
        return job
    }

    override fun findById(id: Long): MemberDataExportJob? {
        return jdbc.query(
            "select * from member_data_exports where id = :id",
            params().withValue("id", id),
            rowMapper,
        ).singleOrNull()
    }

    override fun findLatestByMemberId(memberId: Long): MemberDataExportJob? {
        return jdbc.query(
            """
                select *
                  from member_data_exports
                 where member_id = :memberId
                 order by requested_at desc, id desc
                 limit 1
            """.trimIndent(),
            params().withValue("memberId", memberId),
            rowMapper,
        ).singleOrNull()
    }

    private fun MemberDataExportJob.toParams() = params()
        .withValue("memberId", memberId)
        .withValue("status", status.name)
        .withValue("requestedAt", requestedAt)
        .withValue("completedAt", completedAt)
        .withValue("expiresAt", expiresAt)
        .withValue("downloadedAt", downloadedAt)
        .withValue("failureReason", failureReason)
        .withValue("contentJson", contentJson)

    private companion object {
        private val rowMapper = RowMapper { rs, _ ->
            MemberDataExportJob(
                id = rs.getLong("id"),
                memberId = rs.getLong("member_id"),
                status = MemberDataExportStatus.valueOf(rs.getString("status")),
                requestedAt = rs.getString("requested_at"),
                completedAt = rs.getString("completed_at"),
                expiresAt = rs.getString("expires_at"),
                downloadedAt = rs.getString("downloaded_at"),
                failureReason = rs.getString("failure_reason"),
                contentJson = rs.getString("content_json"),
            )
        }
    }
}
