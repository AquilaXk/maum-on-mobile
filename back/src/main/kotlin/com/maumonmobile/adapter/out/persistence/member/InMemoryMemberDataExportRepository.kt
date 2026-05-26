package com.maumonmobile.adapter.out.persistence.member

import com.maumonmobile.application.port.out.MemberDataExportRepository
import com.maumonmobile.domain.member.MemberDataExportJob
import org.springframework.context.annotation.Profile
import org.springframework.stereotype.Repository
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicLong

@Repository
@Profile("memory")
class InMemoryMemberDataExportRepository : MemberDataExportRepository {
    private val sequence = AtomicLong(1L)
    private val jobsById = ConcurrentHashMap<Long, MemberDataExportJob>()

    override fun save(job: MemberDataExportJob): MemberDataExportJob {
        val savedJob = if (job.id == 0L) {
            job.copy(id = sequence.getAndIncrement())
        } else {
            job
        }
        jobsById[savedJob.id] = savedJob
        return savedJob
    }

    override fun findById(id: Long): MemberDataExportJob? = jobsById[id]

    override fun findLatestByMemberId(memberId: Long): MemberDataExportJob? {
        return jobsById.values
            .filter { job -> job.memberId == memberId }
            .maxWithOrNull(compareBy<MemberDataExportJob> { job -> job.requestedAt }.thenBy { job -> job.id })
    }
}
