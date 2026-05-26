package com.maumonmobile.application.port.out

import com.maumonmobile.domain.member.MemberDataExportJob

interface MemberDataExportRepository {
    fun save(job: MemberDataExportJob): MemberDataExportJob

    fun findById(id: Long): MemberDataExportJob?

    fun findLatestByMemberId(memberId: Long): MemberDataExportJob?
}
