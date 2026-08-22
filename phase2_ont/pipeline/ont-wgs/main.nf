#!/usr/bin/env nextflow
/*
 * ont-wgs — Oxford Nanopore human WGS germline pipeline.
 * See nextflow.config header and README.md for usage. Zero plugins by design.
 */
nextflow.enable.dsl = 2

VALID_TYPES = ['fastq', 'ubam', 'aligned_bam']
// sample/dataset become path components of <outdir>/<sample>/<platform>/<dataset>, so '.' and
// '..' must be excluded outright — '..' would publish outside --outdir
NAME_RE     = ~/^(?!\.{1,2}$)[A-Za-z0-9._-]+$/

def helpMessage() {
    log.info """
    ont-wgs v${workflow.manifest.version}
    ============================================
    Usage:
      nextflow run pipeline/ont-wgs -profile singularity \\
        --input samplesheet.csv --fasta GRCh38.fa --outdir results \\
        --clair3_model r1041_e82_400bps_sup_v430

    Samplesheet (CSV, header required):
      sample,dataset,input_type,file[,index][,unit]
        sample      e.g. HG002                     [A-Za-z0-9._-]
        dataset     e.g. guppy-V3.4.5              [A-Za-z0-9._-]
        input_type  fastq | ubam | aligned_bam
        file        path to .fastq(.gz) / unaligned .bam / sorted .bam
        index       optional: .bai (aligned_bam only)
        unit        optional: 정렬 단위 이름. 비우면 파일명에서 만든다.
                    같은 unit을 가진 ubam 행 여러 개는 정렬 전에 samtools cat으로 합친다
                    (플로우셀 하나가 uBAM 수백 개로 쪼개져 오는 경우용)
      Rows sharing (sample,dataset) are merged after alignment.

    Key params (see nextflow.config for all):
      --fasta                  reference FASTA (required)
      --ref_name               name used in output files [default: fasta basename]
      --clair3_model           /opt/models 또는 --clair3_model_dir 안의 모델 이름
      --clair3_model_dir       컨테이너에 없는 모델을 담은 디렉토리
      --skip_deepvariant       R9.4.1 데이터에서는 필수 (ONT_R104는 R10.4.1 전용 모델)
      --skip_clair3 / --skip_sniffles / --skip_phasing / --skip_qc
      --sniffles_tandem_repeats  TRF bed (권장)
      --phase_vcf              clair3 | deepvariant  [clair3]
      --phase_sv               Sniffles2 VCF도 같이 위상 [true]
      --gvcf                   DeepVariant gVCF도 출력
    Profiles: docker, singularity, sge (combine: -profile sge,singularity), test
    """.stripIndent()
}

def parseSamplesheet(sheet) {
    def lines = sheet.readLines().findAll { it.trim() && !it.startsWith('#') }
    if (lines.size() < 2) error "Samplesheet ${sheet} has no data rows"
    def header  = lines[0].split(',', -1)*.trim()
    def missing = ['sample', 'dataset', 'input_type', 'file'].findAll { !(it in header) }
    if (missing) error "Samplesheet is missing required column(s): ${missing.join(', ')}"
    def rows = []
    lines.tail().eachWithIndex { line, i ->
        def vals = line.split(',', -1)*.trim()
        if (vals.size() != header.size())
            error "Samplesheet line ${i + 2}: expected ${header.size()} fields, got ${vals.size()}: '${line}'"
        def row = [header, vals].transpose().collectEntries { k, v -> [k, v] }
        def nameHelp = "allowed: A-Za-z0-9._- ; '.' and '..' are rejected because the value " +
                       "becomes an output path component"
        if (!(row.sample ==~ NAME_RE))  error "Line ${i + 2}: bad sample '${row.sample}' (${nameHelp})"
        if (!(row.dataset ==~ NAME_RE)) error "Line ${i + 2}: bad dataset '${row.dataset}' (${nameHelp})"
        if (!(row.input_type in VALID_TYPES))
            error "Line ${i + 2}: input_type '${row.input_type}' not one of ${VALID_TYPES.join('|')}"
        if (!row.file) error "Line ${i + 2}: 'file' is empty"
        if (row.index && row.input_type != 'aligned_bam')
            error "Line ${i + 2}: index column must be empty for ${row.input_type}"
        if (row.index && !row.index.endsWith('.bai'))
            error "Line ${i + 2}: index for aligned_bam must be a .bai"
        if (row.unit && !(row.unit ==~ NAME_RE))
            error "Line ${i + 2}: bad unit '${row.unit}' (${nameHelp})"
        rows << row
    }
    return rows
}

def resolvePath(spec, base) {
    // 샘플시트의 상대경로는 **샘플시트가 있는 디렉토리** 기준으로 푼다 (launchDir 기준이 아니다).
    // 절대경로와 URL은 그대로 둔다. assets/samplesheet.test.csv가 이 규칙에 의존한다.
    return (spec.startsWith('/') || spec.contains('://')) ? file(spec) : file("${base}/${spec}")
}

def unitName(path) {
    // unit id from filename: strip common extensions
    def n = path.getName()
    n = n.replaceAll(/\.(fastq|fq)\.gz$/, '')
    n = n.replaceAll(/\.(bam|fastq|fq)$/, '')
    return n
}

def rowUnit(row) { row.unit ?: unitName(file(row.file)) }   // 이름만 쓰므로 존재 확인은 안 한다

workflow {

    if (params.containsKey('help') && params.help) { helpMessage(); exit 0 }
    if (!params.input) { helpMessage(); error "--input samplesheet.csv is required" }
    if (!params.fasta) { helpMessage(); error "--fasta reference.fa is required" }
    if (!(params.phase_vcf in ['deepvariant', 'clair3']))
        error "--phase_vcf must be 'deepvariant' or 'clair3'"
    if (!params.skip_phasing && params.phase_vcf == 'deepvariant' && params.skip_deepvariant)
        error "--phase_vcf deepvariant conflicts with --skip_deepvariant (use --phase_vcf clair3 or --skip_phasing)"
    if (!params.skip_phasing && params.phase_vcf == 'clair3' && params.skip_clair3)
        error "--phase_vcf clair3 conflicts with --skip_clair3 (use --phase_vcf deepvariant or --skip_phasing)"

    def ref_name  = params.ref_name ?: file(params.fasta).getBaseName()
    def sheet     = file(params.input, checkIfExists: true)
    def sheet_dir = sheet.getParent()
    def rows      = parseSamplesheet(sheet)

    // ---- fail fast on the collision modes that would otherwise pass silently -------
    def dup_file = rows.countBy { it.file }.findAll { it.value > 1 }
    if (dup_file)
        error "Samplesheet lists the same file more than once: ${dup_file.keySet().join(', ')}"

    // ubam 행은 unit이 같으면 합치는 게 정상 동작이지만, fastq/aligned_bam은 unit이 겹치면
    // 산출 파일명이 충돌한다 (unit = 정렬 BAM 이름)
    def dup_unit = rows.findAll { it.input_type != 'ubam' }
                       .countBy { [it.sample, it.dataset, rowUnit(it)] }
                       .findAll { it.value > 1 }
    if (dup_unit)
        error "Rows within one (sample,dataset) resolve to the same unit name: " +
              "${dup_unit.keySet().join(' ; ')}. Rename the inputs or set the 'unit' column."
    // 한 unit 안에 ubam과 다른 타입이 섞이면 합치기 규칙이 모호해진다
    def mixed = rows.groupBy { [it.sample, it.dataset, rowUnit(it)] }
                    .findAll { k, v -> v*.input_type.unique().size() > 1 }
    if (mixed)
        error "One unit mixes input types: ${mixed.keySet().join(' ; ')}"

    // '.' is legal inside both names, so distinct groups can compose the same meta.id
    // ("A.B"+"C" and "A"+"B.C" both give A.B.C) — every published filename and the flat
    // MultiQC input directory derive from that id, so collisions would silently drop reports.
    def groups  = rows.groupBy { [it.sample, it.dataset] }
    def dup_id  = groups.keySet().groupBy { s, d -> "${s}.${d}".toString() }
                        .findAll { it.value.size() > 1 }
    if (dup_id)
        error "Distinct (sample,dataset) groups compose the same output id: " +
              dup_id.collect { id, pairs -> "${id} <- ${pairs}" }.join(' ; ') +
              ". Rename one of them (the '.' placement differs but the composed id does not)."

    // groupTuple 크기: 정렬 BAM 개수 = 그룹 안의 서로 다른 unit 수 (행 수가 아니다)
    def n_units      = groups.collectEntries { k, v -> [k, v.collect { rowUnit(it) }.unique().size()] }
    def unit_sizes   = rows.countBy { [it.sample, it.dataset, rowUnit(it)] }

    log.info "ont-wgs v${workflow.manifest.version} | ${rows.size()} row(s), " +
             "${groups.size()} sample-dataset group(s), ${n_units.values().sum()} unit(s) | ref: ${ref_name}"

    ch_fasta = Channel.value(file(params.fasta, checkIfExists: true))

    ch_rows = Channel.fromList(rows).map { r ->
        def f    = resolvePath(r.file, sheet_dir)
        if (!f.exists()) error "Samplesheet file does not exist: ${f}"
        def idx  = r.index ? resolvePath(r.index, sheet_dir) : null
        if (idx && !idx.exists()) error "Samplesheet index does not exist: ${idx}"
        def meta = [sample: r.sample, dataset: r.dataset, type: r.input_type, unit: rowUnit(r)]
        tuple(meta, f, idx)
    }

    ch_in = ch_rows.branch {
        ubam:     it[0].type == 'ubam'
        fastq:    it[0].type == 'fastq'
        aligned:  it[0].type == 'aligned_bam'
    }

    // ---- reference prep -------------------------------------------------
    SAMTOOLS_FAIDX(ch_fasta)
    ch_fai = SAMTOOLS_FAIDX.out.fai

    // ---- entry point 1: unaligned BAM -----------------------------------
    // 한 unit이 uBAM 여러 개로 쪼개져 있으면 (HG008T-p2는 플로우셀당 500+) 먼저 합친다.
    // samtools cat은 블록을 그대로 이어 붙이므로 재압축이 없고, MM/ML 태그도 그대로다.
    ch_ubam_grouped = ch_in.ubam
        .map { m, f, i ->
            def key = "${m.sample}\t${m.dataset}\t${m.unit}".toString()
            tuple(groupKey(key, unit_sizes[[m.sample, m.dataset, m.unit]]), f)
        }
        .groupTuple()
        .map { key, files ->
            def (s, d, u) = key.toString().split('\t')
            // 도착 순서는 실행마다 달라진다 — 정렬해서 task hash를 고정해야 -resume이 산다
            tuple([sample: s, dataset: d, type: 'ubam', unit: u], files.sort { it.name })
        }
        .branch {
            multi:  it[1].size() > 1
            single: true
        }

    SAMTOOLS_CAT(ch_ubam_grouped.multi)
    ch_ubam = SAMTOOLS_CAT.out.bam
        .mix(ch_ubam_grouped.single.map { m, files -> tuple(m, files[0]) })

    // ---- entry points 1+2 -> minimap2 -----------------------------------
    // 전장 .mmi 빌드는 ~11 GB를 쓰고 MINIMAP2_INDEX는 value 채널을 받으므로
    // 정렬할 게 없는 실행에서도 돌아버린다 — 샘플시트에 정렬 대상이 있을 때만 켠다.
    ch_aligned_new = Channel.empty()
    if (rows.any { it.input_type != 'aligned_bam' }) {
        MINIMAP2_INDEX(ch_fasta)
        ch_align_in = ch_ubam.mix(ch_in.fastq.map { m, f, i -> tuple(m, f) })
        MINIMAP2_ALIGN(ch_align_in, MINIMAP2_INDEX.out.mmi)
        ch_aligned_new = MINIMAP2_ALIGN.out.bam
    }

    // ---- entry point 3: pre-aligned BAM ----------------------------------
    ch_pre = ch_in.aligned.branch {
        with_bai: it[2] != null
        no_bai:   true
    }
    SAMTOOLS_INDEX_INPUT(ch_pre.no_bai.map { m, f, i -> tuple(m, f) })
    ch_prealigned = ch_pre.with_bai
        .map { m, f, i -> tuple(m, f, i, 'preexisting') }
        .mix(SAMTOOLS_INDEX_INPUT.out.indexed.map { m, f, i -> tuple(m, f, i, 'preexisting') })

    // ---- group per (sample,dataset), merge if multiple units -------------
    ch_grouped = ch_aligned_new
        .map { m, bam, bai -> tuple(m, bam, bai, 'new') }
        .mix(ch_prealigned)
        .map { m, bam, bai, origin ->
            def key = "${m.sample}\t${m.dataset}".toString()
            tuple(groupKey(key, n_units[[m.sample, m.dataset]]), bam, bai, origin)
        }
        .groupTuple()
        .map { key, bams, bais, origins ->
            def (s, d) = key.toString().split('\t')
            def trip = [bams, bais, origins].transpose().sort { a, b -> a[0].name <=> b[0].name }
            tuple([sample: s, dataset: d, id: "${s}.${d}".toString()],
                  trip.collect { it[0] }, trip.collect { it[1] }, trip.collect { it[2] })
        }
        .branch {
            passthrough: it[1].size() == 1 && it[3][0] == 'preexisting'
            finalize:    true
        }

    FINALIZE_BAM(ch_grouped.finalize.map { m, bams, bais, o -> tuple(m, bams, bais) }, ref_name)

    // 조용히 틀리는 두 가지를 막는다: --fasta와 다른 레퍼런스에 정렬된 BAM(키메릭 병합,
    // 콜러 산출 0건), 그리고 mapped 리드 0인 BAM(모든 콜러가 빈 VCF를 내고 성공한다)
    CHECK_BAM(
        FINALIZE_BAM.out.bam
            .mix(ch_grouped.passthrough.map { m, bams, bais, o -> tuple(m, bams[0], bais[0]) }),
        ch_fai
    )
    ch_bam = CHECK_BAM.out.bam

    // ---- small variants ---------------------------------------------------
    ch_dv_vcf     = Channel.empty()
    ch_clair3_vcf = Channel.empty()
    if (!params.skip_deepvariant) {
        DEEPVARIANT(ch_bam, ch_fasta, ch_fai, ref_name)
        ch_dv_vcf = DEEPVARIANT.out.vcf
    }
    if (!params.skip_clair3) {
        ch_model_dir = params.clair3_model_dir
            ? Channel.value(file(params.clair3_model_dir, checkIfExists: true))
            : Channel.value(file("${projectDir}/assets/NO_MODEL_DIR"))
        CLAIR3(ch_bam, ch_fasta, ch_fai, ch_model_dir, ref_name)
        ch_clair3_vcf = CLAIR3.out.vcf
    }

    // ---- structural variants ----------------------------------------------
    ch_sv_vcf = Channel.empty()
    if (!params.skip_sniffles) {
        ch_trf = params.sniffles_tandem_repeats
            ? Channel.value(file(params.sniffles_tandem_repeats, checkIfExists: true))
            : Channel.value(file("${projectDir}/assets/NO_TRF"))
        SNIFFLES(ch_bam, ch_fasta, ch_fai, ch_trf, ref_name)
        BCFTOOLS_SORT_SV(SNIFFLES.out.vcf_raw)
        ch_sv_vcf = BCFTOOLS_SORT_SV.out.vcf
    }

    // ---- phasing + haplotagging (LongPhase) --------------------------------
    ch_phased_vcf = Channel.empty()
    if (!params.skip_phasing) {
        ch_phase_src = params.phase_vcf == 'deepvariant' ? ch_dv_vcf : ch_clair3_vcf
        // SV를 같이 위상하면 소변이 위상 정확도도 올라간다. sniffles를 끈 실행에서는 센티넬을 넘긴다.
        ch_phase_in  = (params.phase_sv && !params.skip_sniffles)
            ? ch_phase_src.join(ch_bam).join(ch_sv_vcf.map { m, v, t -> tuple(m, v) })
            : ch_phase_src.join(ch_bam)
                  .map { m, v, t, b, i -> tuple(m, v, t, b, i, file("${projectDir}/assets/NO_SV_VCF")) }
        LONGPHASE_PHASE(ch_phase_in, ch_fasta, ch_fai, ref_name)
        BGZIP_PHASED(LONGPHASE_PHASE.out.vcf)
        // 위상된 SV VCF는 SV가 실제로 나왔을 때만 흐른다 (optional 출력). 별도 프로세스라
        // 채널이 비면 그냥 돌지 않는다 — optional을 join에 섞지 않는 게 요점이다.
        BGZIP_PHASED_SV(LONGPHASE_PHASE.out.sv)
        ch_phased_vcf = BGZIP_PHASED.out.vcf
        WHATSHAP_STATS(ch_phased_vcf, ref_name)
        // haplotag는 소변이 위상 블록만 쓴다 (표준). 위상된 SV는 산출물로만 남긴다.
        LONGPHASE_HAPLOTAG(ch_phased_vcf.join(ch_bam), ch_fasta, ch_fai, ref_name)
        SAMTOOLS_INDEX_HAPLOTAG(LONGPHASE_HAPLOTAG.out.bam)
    }

    // ---- SNV / indel convenience splits ------------------------------------
    ch_split_in = ch_dv_vcf.map     { m, v, t -> tuple(m, 'deepvariant', v, t) }
        .mix(ch_clair3_vcf.map      { m, v, t -> tuple(m, 'clair3', v, t) })
    BCFTOOLS_SPLIT(ch_split_in, ch_fasta, ch_fai, ref_name)

    // ---- QC -----------------------------------------------------------------
    if (!params.skip_qc) {
        MOSDEPTH(ch_bam, ref_name)
        SAMTOOLS_STATS(ch_bam, ref_name)
        ch_stats_in = ch_dv_vcf.map { m, v, t -> tuple(m, 'deepvariant', v) }
            .mix(ch_clair3_vcf.map  { m, v, t -> tuple(m, 'clair3', v) })
            .mix(ch_sv_vcf.map      { m, v, t -> tuple(m, 'sniffles', v) })
        BCFTOOLS_STATS(ch_stats_in, ref_name)

        ch_mqc = MOSDEPTH.out.reports.map { m, f -> f }.flatten()
            .mix(SAMTOOLS_STATS.out.reports.map { m, f -> f }.flatten())
            .mix(BCFTOOLS_STATS.out.reports.map { m, f -> f }.flatten())
        if (!params.skip_phasing)
            ch_mqc = ch_mqc.mix(WHATSHAP_STATS.out.reports.map { m, f -> f }.flatten())
        MULTIQC(ch_mqc.collect())
    }

}

workflow.onComplete {
    log.info "ont-wgs finished: ${workflow.success ? 'OK' : 'FAILED'} | outdir: ${params.outdir}"
}

/* ===========================================================================
 * Processes
 * =========================================================================== */

def outbase(meta) { "${params.outdir}/${meta.sample}/${params.platform_subdir}/${meta.dataset}" }

process SAMTOOLS_FAIDX {
    label 'process_low'
    container params.container_samtools
    input:  path fasta
    output: path "${fasta}.fai", emit: fai
    script:
    """
    samtools faidx ${fasta}
    """
    stub:
    """
    touch ${fasta}.fai
    """
}

process SAMTOOLS_CAT {
    tag "${meta.sample}.${meta.dataset}:${meta.unit}"
    label 'process_medium'
    container params.container_samtools
    input:  tuple val(meta), path(bams, stageAs: 'in/*')
    output: tuple val(meta), path("${meta.unit}.ubam.bam"), emit: bam
    script:
    """
    # samtools cat: BGZF 블록을 그대로 이어 붙인다 (재압축 없음, 태그 보존).
    # 파일 목록을 -b로 넘긴다 — uBAM이 수백 개면 ARG_MAX에 걸린다.
    ls in/*.bam | sort > cat_list.txt
    n=\$(wc -l < cat_list.txt)
    if [ "\$n" -lt 2 ]; then echo "ERROR: SAMTOOLS_CAT got \$n file(s)" >&2; exit 1; fi
    samtools cat -b cat_list.txt -o ${meta.unit}.ubam.bam
    """
    stub:
    """
    touch ${meta.unit}.ubam.bam
    """
}

process MINIMAP2_INDEX {
    label 'process_high'
    container params.container_minimap2
    input:  path fasta
    output: path "${fasta.baseName}.${params.minimap2_preset}.mmi", emit: mmi
    script:
    // preset(-k/-w)이 .mmi 안에 구워진다. 다른 preset으로 align하면 minimap2는 인덱스 쪽
    // 파라미터를 조용히 쓴다 — 그래서 파일명에 preset을 박아 둔다.
    """
    minimap2 -x ${params.minimap2_preset} -t ${task.cpus} \\
        -d ${fasta.baseName}.${params.minimap2_preset}.mmi ${fasta}
    """
    stub:
    """
    touch ${fasta.baseName}.${params.minimap2_preset}.mmi
    """
}

process MINIMAP2_ALIGN {
    tag "${meta.unit}"
    label 'process_high'
    container params.container_minimap2
    input:
        tuple val(meta), path(reads)
        path mmi
    output: tuple val(meta), path("${meta.unit}.aligned.bam"), path("${meta.unit}.aligned.bam.bai"), emit: bam
    script:
    def sort_t = Math.max(2, (task.cpus / 6) as int)
    def mm_t   = Math.max(1, task.cpus - sort_t - 2)
    def is_bam = reads.name.endsWith('.bam')
    // uBAM 진입: samtools fastq -T 가 태그를 리드 코멘트로 옮기고, minimap2 -y 가 그 코멘트를
    // 다시 BAM 태그로 넣는다. 이게 MM/ML(5mC/5hmC)을 살리는 경로다.
    // 원본 @RG(dorado 모델 문자열)는 fastq를 거치며 사라지므로 아래에서 새로 붙인다 —
    // 베이스콜러/모델은 run_table.tsv의 basecaller 열에 기록해 둔다.
    //
    // -y를 fastq 진입에 주면 안 된다: Guppy/dorado가 뽑은 fastq의 헤더 코멘트는
    // 'runid=... ch=... start_time=...' 꼴이라 SAM aux(TAG:TYPE:VALUE) 형식이 아니다.
    // 그걸 그대로 옮기면 BAM이 깨진다. 그래서 uBAM 진입에서만 붙인다.
    def tag_arg = is_bam ? '-y' : ''
    def rg = "@RG\\tID:${meta.unit}\\tSM:${meta.sample}\\tPL:ONT\\tPU:${meta.unit}"
    def src = is_bam ? "samtools fastq -@ 2 -T ${params.ubam_tags} ${reads} |" : ''
    def query = is_bam ? '-' : "${reads}"
    """
    ${src} minimap2 -ax ${params.minimap2_preset} -t ${mm_t} \\
        -R '${rg}' ${tag_arg} ${params.minimap2_args} \\
        ${mmi} ${query} \\
      | samtools sort -@ ${sort_t} -m ${params.minimap2_sort_mem} \\
        --write-index -o ${meta.unit}.aligned.bam##idx##${meta.unit}.aligned.bam.bai -
    """
    stub:
    """
    touch ${meta.unit}.aligned.bam ${meta.unit}.aligned.bam.bai
    """
}

process SAMTOOLS_INDEX_INPUT {
    tag "${meta.unit}"
    label 'process_low'
    container params.container_samtools
    input:  tuple val(meta), path(bam)
    output: tuple val(meta), path(bam), path("${bam}.bai"), emit: indexed
    script:
    """
    samtools index -@ ${task.cpus} ${bam}
    """
    stub:
    """
    touch ${bam}.bai
    """
}

process FINALIZE_BAM {
    tag "${meta.id}"
    label 'process_medium'
    container params.container_samtools
    publishDir path: { "${outbase(meta)}/02_alignedBAM" }, mode: 'copy'
    input:
        tuple val(meta), path(bams, stageAs: 'in/*'), path(bais, stageAs: 'in/*')
        val ref_name
    output: tuple val(meta), path("${meta.id}.${ref_name}.bam"), path("${meta.id}.${ref_name}.bam.bai"), emit: bam
    script:
    // Nextflow가 1개짜리 컬렉션을 bare Path로 풀어 버리는데, Path.size()는 바이트 크기다 —
    // 개수를 세기 전에 정규화한다
    def bam_list = bams instanceof List ? bams : [bams]
    def out = "${meta.id}.${ref_name}.bam"
    if (bam_list.size() > 1)
        """
        samtools merge -@ ${task.cpus} -o ${out} in/*.bam
        samtools index -@ ${task.cpus} ${out}
        """
    else
        """
        ln -f \$(readlink -f in/*.bam) ${out} 2>/dev/null || cp in/*.bam ${out}
        samtools index -@ ${task.cpus} ${out}
        """
    stub:
    """
    touch ${meta.id}.${ref_name}.bam ${meta.id}.${ref_name}.bam.bai
    """
}

process CHECK_BAM {
    tag "${meta.id}"
    container params.container_samtools
    input:
        tuple val(meta), path(bam), path(bai)
        path fai
    output: tuple val(meta), path(bam), path(bai), emit: bam
    script:
    """
    # 이름만이 아니라 NAME+LENGTH를 비교한다: 같은 contig 이름에 길이가 다르면 다른 빌드라는 뜻이고
    # (예: GRCh37 chr20 BAM vs GRCh38 chr20 FASTA), 그대로 통과시키면 좌표가 어긋난 콜이 나온다.
    samtools view -H ${bam} \\
      | awk -F'\\t' '\$1=="@SQ"{n="";l=""; for(i=2;i<=NF;i++){ if(\$i ~ /^SN:/) n=substr(\$i,4); if(\$i ~ /^LN:/) l=substr(\$i,4)} if(n!="") print n"\\t"l}' \\
      | sort > bam_contigs.txt
    cut -f1,2 ${fai} | sort > ref_contigs.txt
    missing=\$(comm -23 bam_contigs.txt ref_contigs.txt)
    if [ -n "\$missing" ]; then
        echo "ERROR: ${bam} has @SQ entries (name<TAB>length) that --fasta does not match —" >&2
        echo "       aligned to a different reference or a different build of it:" >&2
        echo "\$missing" | head >&2
        echo "       reference has:" >&2
        cut -f1 ${fai} | sort | head >&2
        exit 1
    fi
    mapped=\$(samtools idxstats ${bam} | awk '{s+=\$3} END{print s+0}')
    if [ "\$mapped" -eq 0 ]; then
        echo "ERROR: ${bam} has zero mapped reads — wrong reference or wrong input type" >&2
        exit 1
    fi
    """
    stub:
    """
    true
    """
}

process DEEPVARIANT {
    tag "${meta.id}"
    label 'process_high'
    container params.container_deepvariant
    publishDir path: { "${outbase(meta)}/03_VCF/deepvariant" }, mode: 'copy'
    input:
        tuple val(meta), path(bam), path(bai)
        path fasta
        path fai
        val ref_name
    output:
        tuple val(meta), path("${meta.id}.${ref_name}.deepvariant.vcf.gz"), path("${meta.id}.${ref_name}.deepvariant.vcf.gz.tbi"), emit: vcf
        path "${meta.id}.${ref_name}.deepvariant.g.vcf.gz*", optional: true, emit: gvcf
        path "${meta.id}.${ref_name}.deepvariant.visual_report.html", optional: true, emit: report
    script:
    def prefix = "${meta.id}.${ref_name}.deepvariant"
    def gvcf   = params.gvcf ? "--output_gvcf=${prefix}.g.vcf.gz" : ''
    """
    export OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1
    mkdir -p dv_intermediate
    /opt/deepvariant/bin/run_deepvariant \\
        --model_type=${params.deepvariant_model} \\
        --ref=${fasta} \\
        --reads=${bam} \\
        --output_vcf=${prefix}.vcf.gz \\
        ${gvcf} \\
        --sample_name=${meta.sample} \\
        --vcf_stats_report=true \\
        --num_shards=${task.cpus} \\
        --intermediate_results_dir=dv_intermediate \\
        ${params.deepvariant_args}
    """
    stub:
    """
    touch ${meta.id}.${ref_name}.deepvariant.vcf.gz ${meta.id}.${ref_name}.deepvariant.vcf.gz.tbi
    """
}

process CLAIR3 {
    tag "${meta.id}"
    label 'process_high'
    container params.container_clair3
    publishDir path: { "${outbase(meta)}/03_VCF/clair3" }, mode: 'copy'
    input:
        tuple val(meta), path(bam), path(bai)
        path fasta
        path fai
        path model_dir
        val ref_name
    output:
        tuple val(meta), path("${meta.id}.${ref_name}.clair3.vcf.gz"), path("${meta.id}.${ref_name}.clair3.vcf.gz.tbi"), emit: vcf
    script:
    def prefix   = "${meta.id}.${ref_name}.clair3"
    def ext      = model_dir.name != 'NO_MODEL_DIR'
    def mpath    = ext ? "${model_dir}/${params.clair3_model}" : "/opt/models/${params.clair3_model}"
    def extra_ls = ext ? "ls ${model_dir}/ >&2 || true" : "true"
    """
    # 모델이 없으면 Clair3는 엉뚱한 오류로 죽거나 조용히 이상한 결과를 낸다.
    # 여기서 먼저 끊고 어떤 모델이 있는지 보여준다.
    if [ ! -d "${mpath}" ]; then
        echo "ERROR: clair3 model not found: ${mpath}" >&2
        echo "  in image /opt/models:" >&2
        ls /opt/models/ >&2 || true
        echo "  in --clair3_model_dir (있으면):" >&2
        ${extra_ls}
        exit 1
    fi
    /opt/bin/run_clair3.sh \\
        --bam_fn=${bam} \\
        --ref_fn=${fasta} \\
        --threads=${task.cpus} \\
        --platform=${params.clair3_platform} \\
        --model_path="${mpath}" \\
        --sample_name=${meta.sample} \\
        --output=clair3_out \\
        ${params.clair3_args}
    mv clair3_out/merge_output.vcf.gz     ${prefix}.vcf.gz
    mv clair3_out/merge_output.vcf.gz.tbi ${prefix}.vcf.gz.tbi
    """
    stub:
    """
    touch ${meta.id}.${ref_name}.clair3.vcf.gz ${meta.id}.${ref_name}.clair3.vcf.gz.tbi
    """
}

process SNIFFLES {
    tag "${meta.id}"
    label 'process_medium'
    container params.container_sniffles
    input:
        tuple val(meta), path(bam), path(bai)
        path fasta
        path fai
        path trf
        val ref_name
    output: tuple val(meta), path("${meta.id}.${ref_name}.sniffles.vcf"), emit: vcf_raw
    script:
    def trf_arg = trf.name != 'NO_TRF' ? "--tandem-repeats ${trf}" : ''
    """
    sniffles --input ${bam} \\
        --vcf ${meta.id}.${ref_name}.sniffles.vcf \\
        --reference ${fasta} \\
        --sample-id ${meta.sample} \\
        --threads ${task.cpus} \\
        ${trf_arg} ${params.sniffles_args}
    """
    stub:
    """
    touch ${meta.id}.${ref_name}.sniffles.vcf
    """
}

process BCFTOOLS_SORT_SV {
    tag "${meta.id}"
    label 'process_low'
    container params.container_bcftools
    publishDir path: { "${outbase(meta)}/03_VCF/SV_sniffles" }, mode: 'copy'
    input:  tuple val(meta), path(vcf)
    output: tuple val(meta), path("${vcf}.gz"), path("${vcf}.gz.tbi"), emit: vcf
    script:
    """
    bcftools sort -Oz -o ${vcf}.gz ${vcf}
    tabix -p vcf ${vcf}.gz
    """
    stub:
    """
    touch ${vcf}.gz ${vcf}.gz.tbi
    """
}

process LONGPHASE_PHASE {
    tag "${meta.id}"
    label 'process_medium'
    container params.container_longphase
    input:
        tuple val(meta), path(vcf), path(tbi), path(bam), path(bai), path(sv_vcf)
        path fasta
        path fai
        val ref_name
    output:
        tuple val(meta), path("${meta.id}.${ref_name}.${params.phase_vcf}.phased.vcf"), emit: vcf
        tuple val(meta), path("${meta.id}.${ref_name}.${params.phase_vcf}.sv_phased.vcf"), optional: true, emit: sv
    script:
    def prefix = "${meta.id}.${ref_name}.${params.phase_vcf}"
    def sv_arg = sv_vcf.name != 'NO_SV_VCF' ? "--sv-file ${sv_vcf}" : ''
    // ONT 심도에서 whatshap phase는 단일 스레드로 너무 느리다. LongPhase는 같은 일을
    // 멀티스레드로 하고 SV까지 같이 위상한다(--sv-file).
    """
    longphase phase \\
        -s ${vcf} ${sv_arg} \\
        -b ${bam} \\
        -r ${fasta} \\
        -t ${task.cpus} \\
        -o lp \\
        --ont ${params.longphase_args}

    # 출력 이름은 longphase 버전에 따라 lp.vcf 또는 lp.vcf.gz다. 둘 다 받고, 없으면 끊는다.
    if   [ -s lp.vcf ];    then mv lp.vcf ${prefix}.phased.vcf
    elif [ -s lp.vcf.gz ]; then gzip -dc lp.vcf.gz > ${prefix}.phased.vcf
    else echo "ERROR: longphase produced no SNV output. 작업 디렉토리:" >&2; ls -la >&2; exit 1; fi
    if   [ -s lp_SV.vcf ];    then mv lp_SV.vcf ${prefix}.sv_phased.vcf
    elif [ -s lp_SV.vcf.gz ]; then gzip -dc lp_SV.vcf.gz > ${prefix}.sv_phased.vcf; fi
    """
    stub:
    """
    touch ${meta.id}.${ref_name}.${params.phase_vcf}.phased.vcf
    touch ${meta.id}.${ref_name}.${params.phase_vcf}.sv_phased.vcf
    """
}

process BGZIP_PHASED {
    tag "${meta.id}"
    label 'process_low'
    container params.container_bcftools
    publishDir path: { "${outbase(meta)}/03_VCF/phased_longphase" }, mode: 'copy'
    input:  tuple val(meta), path(vcf)
    output: tuple val(meta), path("${vcf}.gz"), path("${vcf}.gz.tbi"), emit: vcf
    script:
    """
    bgzip -c ${vcf} > ${vcf}.gz
    tabix -p vcf ${vcf}.gz
    """
    stub:
    """
    touch ${vcf}.gz ${vcf}.gz.tbi
    """
}

process BGZIP_PHASED_SV {
    tag "${meta.id}"
    label 'process_low'
    container params.container_bcftools
    publishDir path: { "${outbase(meta)}/03_VCF/phased_longphase" }, mode: 'copy'
    input:  tuple val(meta), path(vcf)
    output: tuple val(meta), path("${vcf}.gz"), path("${vcf}.gz.tbi"), emit: vcf
    script:
    """
    bgzip -c ${vcf} > ${vcf}.gz
    tabix -p vcf ${vcf}.gz
    """
    stub:
    """
    touch ${vcf}.gz ${vcf}.gz.tbi
    """
}

process WHATSHAP_STATS {
    tag "${meta.id}"
    label 'process_low'
    container params.container_whatshap
    publishDir path: { "${outbase(meta)}/03_VCF/phased_longphase" }, mode: 'copy'
    input:
        tuple val(meta), path(vcf), path(tbi)
        val ref_name
    output: tuple val(meta), path("${meta.id}.${ref_name}.whatshap_stats.txt"), emit: reports
    script:
    // 위상은 LongPhase가 하지만 지표(블록 N50 등)는 whatshap stats가 표준이고 MultiQC가 읽는다
    """
    whatshap stats --tsv=${meta.id}.${ref_name}.whatshap_stats.txt ${vcf}
    """
    stub:
    """
    touch ${meta.id}.${ref_name}.whatshap_stats.txt
    """
}

process LONGPHASE_HAPLOTAG {
    tag "${meta.id}"
    label 'process_medium'
    container params.container_longphase
    input:
        tuple val(meta), path(vcf), path(tbi), path(bam), path(bai)
        path fasta
        path fai
        val ref_name
    output: tuple val(meta), path("${meta.id}.${ref_name}.haplotagged.bam"), emit: bam
    script:
    """
    longphase haplotag \\
        -s ${vcf} \\
        -b ${bam} \\
        -r ${fasta} \\
        -t ${task.cpus} \\
        -o ${meta.id}.${ref_name}.haplotagged
    """
    stub:
    """
    touch ${meta.id}.${ref_name}.haplotagged.bam
    """
}

process SAMTOOLS_INDEX_HAPLOTAG {
    tag "${meta.id}"
    label 'process_low'
    container params.container_samtools
    publishDir path: { "${outbase(meta)}/02_alignedBAM/haplotagged" }, mode: 'copy'
    input:  tuple val(meta), path(bam)
    output: tuple val(meta), path(bam), path("${bam}.bai"), emit: bam
    script:
    """
    samtools index -@ ${task.cpus} ${bam}
    """
    stub:
    """
    touch ${bam}.bai
    """
}

process BCFTOOLS_SPLIT {
    tag "${meta.id}:${caller}"
    label 'process_low'
    container params.container_bcftools
    publishDir path: { "${outbase(meta)}/03_VCF/SNV_${caller}" },   mode: 'copy', pattern: '*.snv.vcf.gz*'
    publishDir path: { "${outbase(meta)}/03_VCF/INDEL_${caller}" }, mode: 'copy', pattern: '*.indel.vcf.gz*'
    input:
        tuple val(meta), val(caller), path(vcf), path(tbi)
        path fasta
        path fai
        val ref_name
    output:
        tuple val(meta), path("${meta.id}.${ref_name}.${caller}.snv.vcf.gz"),   path("${meta.id}.${ref_name}.${caller}.snv.vcf.gz.tbi"),   emit: snv
        tuple val(meta), path("${meta.id}.${ref_name}.${caller}.indel.vcf.gz"), path("${meta.id}.${ref_name}.${caller}.indel.vcf.gz.tbi"), emit: indel
    script:
    def prefix = "${meta.id}.${ref_name}.${caller}"
    """
    # multiallelic을 먼저 쪼개서 SNP+indel 혼합 레코드가 정확히 한쪽에만 들어가게 한다
    bcftools norm -f ${fasta} -m -any --check-ref w -Oz -o norm.vcf.gz ${vcf}
    tabix -p vcf norm.vcf.gz
    bcftools view -v snps   -Oz -o ${prefix}.snv.vcf.gz   norm.vcf.gz
    tabix -p vcf ${prefix}.snv.vcf.gz
    bcftools view -v indels -Oz -o ${prefix}.indel.vcf.gz norm.vcf.gz
    tabix -p vcf ${prefix}.indel.vcf.gz
    """
    stub:
    """
    touch ${meta.id}.${ref_name}.${caller}.snv.vcf.gz ${meta.id}.${ref_name}.${caller}.snv.vcf.gz.tbi
    touch ${meta.id}.${ref_name}.${caller}.indel.vcf.gz ${meta.id}.${ref_name}.${caller}.indel.vcf.gz.tbi
    """
}

process MOSDEPTH {
    tag "${meta.id}"
    label 'process_low'
    container params.container_mosdepth
    publishDir path: { "${outbase(meta)}/04_QC/mosdepth" }, mode: 'copy'
    input:
        tuple val(meta), path(bam), path(bai)
        val ref_name
    output: tuple val(meta), path("${meta.id}.${ref_name}.{mosdepth,regions}.*"), emit: reports
    script:
    """
    mosdepth -t ${task.cpus} --no-per-base --by 500 ${meta.id}.${ref_name} ${bam}
    """
    stub:
    """
    touch ${meta.id}.${ref_name}.mosdepth.global.dist.txt ${meta.id}.${ref_name}.mosdepth.summary.txt \\
          ${meta.id}.${ref_name}.mosdepth.region.dist.txt ${meta.id}.${ref_name}.regions.bed.gz
    """
}

process SAMTOOLS_STATS {
    tag "${meta.id}"
    label 'process_low'
    container params.container_samtools
    publishDir path: { "${outbase(meta)}/04_QC/samtools" }, mode: 'copy'
    input:
        tuple val(meta), path(bam), path(bai)
        val ref_name
    output: tuple val(meta), path("${meta.id}.${ref_name}.{stats,flagstat}.txt"), emit: reports
    script:
    """
    samtools stats -@ ${task.cpus} ${bam} > ${meta.id}.${ref_name}.stats.txt
    samtools flagstat -@ ${task.cpus} ${bam} > ${meta.id}.${ref_name}.flagstat.txt
    """
    stub:
    """
    touch ${meta.id}.${ref_name}.stats.txt ${meta.id}.${ref_name}.flagstat.txt
    """
}

process BCFTOOLS_STATS {
    tag "${meta.id}:${caller}"
    label 'process_low'
    container params.container_bcftools
    publishDir path: { "${outbase(meta)}/04_QC/bcftools_stats" }, mode: 'copy'
    input:
        tuple val(meta), val(caller), path(vcf)
        val ref_name
    output: tuple val(meta), path("${meta.id}.${ref_name}.${caller}.bcftools_stats.txt"), emit: reports
    script:
    """
    bcftools stats ${vcf} > ${meta.id}.${ref_name}.${caller}.bcftools_stats.txt
    """
    stub:
    """
    touch ${meta.id}.${ref_name}.${caller}.bcftools_stats.txt
    """
}

process MULTIQC {
    label 'process_low'
    container params.container_multiqc
    publishDir path: { "${params.outdir}/multiqc/${params.run_label}" }, mode: 'copy'
    input:  path 'qc_inputs/*'
    output: path "multiqc_report.html", emit: report
            path "multiqc_report_data", emit: data
    script:
    """
    multiqc -f --title ont-wgs -n multiqc_report.html qc_inputs
    """
    stub:
    """
    touch multiqc_report.html
    mkdir -p multiqc_report_data
    """
}
