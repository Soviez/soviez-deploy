rule Soviez_Miner_XMRig
{
    meta:
        description = "XMRig miner indicator"
        severity = "CRITICAL"
        id = "SYARA001"
    strings:
        $a = "xmrig" nocase
        $b = "stratum+tcp://" nocase
        $c = "donate-level" nocase
    condition:
        2 of them
}

rule Soviez_ReverseShell_Bash
{
    meta:
        description = "Bash reverse shell patterns"
        severity = "CRITICAL"
        id = "SYARA002"
    strings:
        $a = "/dev/tcp/" ascii
        $b = "bash -i" ascii
        $c = "mkfifo /tmp/" ascii
    condition:
        any of them
}

rule Soviez_Downloader_CurlBash
{
    meta:
        description = "curl|bash downloader"
        severity = "HIGH"
        id = "SYARA003"
    strings:
        $a = /curl[^\n]{0,80}\|\s*(ba)?sh/
        $b = /wget[^\n]{0,80}\|\s*(ba)?sh/
    condition:
        any of them
}
