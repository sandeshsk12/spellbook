{{ config(
    schema = 'rollup_economics_linea'
    , alias = 'l1_verification_fees'  
    , materialized = 'incremental'
    , file_format = 'delta'
    , incremental_strategy = 'merge'
    , unique_key = ['name', 'tx_hash']
    , incremental_predicates = [incremental_predicate('DBT_INTERNAL_DEST.block_time')]
)}}

SELECT
    'linea' AS name
    , cast(date_trunc('month', t.block_time) AS date) AS block_month
    , cast(date_trunc('day', t.block_time) AS date) AS block_date
    , t.block_time
    , t.block_number
    , t.hash AS tx_hash
    , t.index AS tx_index
    , t.gas_price
    , t.gas_used
    , (t.gas_price / 1e18) * t.gas_used AS verification_fee_native
    , {{ evm_get_calldata_gas_from_data('t.data') }} AS calldata_gas_used
    , 44*32 / cast(1024 AS double) / cast(1024 AS double) AS proof_size_mb
FROM {{ source('ethereum', 'transactions') }} t
WHERE t.to IN (
    0xd19d4B5d358258f05D7B411E21A1460D11B0876F -- Linea, L1 Message Service
)
AND bytearray_substring(t.data, 1, 4) IN (
    0x4165d6dd -- Finalize Blocks (proof verified immediately)
    , 0x5603c65f -- Finalize Blocks (updated)
    , 0xd630280f -- finalizeCompressedBlocksWithProof (Aplha v2 Release at block. 19222438)
    , 0xabffac32 -- finalizeBlocksWithProof
)
AND t.block_time >= TIMESTAMP '2023-07-12'
{% if is_incremental() %}
AND {{incremental_predicate('t.block_time')}}
{% endif %}
