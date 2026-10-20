# NFS II SE - Gerador de texto PT-BR (PowerShell do Windows)
$ErrorActionPreference = 'Stop'
try {
    $pasta = Split-Path -Parent $MyInvocation.MyCommand.Path
    $csvPath = Join-Path $pasta 'NFSIISE_PTBR.csv'
    $basePath = Join-Path $pasta 'text.original.eng'
    $saida = Join-Path $pasta 'text.eng'
    if (-not (Test-Path -LiteralPath $csvPath)) { throw 'CSV nao encontrado.' }
    if (-not (Test-Path -LiteralPath $basePath)) { throw 'Arquivo original nao encontrado.' }
    $registros = @(Import-Csv -LiteralPath $csvPath -Delimiter ',' -Encoding UTF8)
    $quantidade = 1502
    if ($registros.Count -ne $quantidade) { throw "CSV deve ter $quantidade linhas; encontrou $($registros.Count)." }
    $original = [System.IO.File]::ReadAllBytes($basePath)
    $inicio = $quantidade * 12
    if ($original.Length -lt $inicio -or [BitConverter]::ToUInt32($original,8) -ne $inicio) {
        throw 'Arquivo original incompativel: tabela de ponteiros inesperada.'
    }
    $encoding = [System.Text.Encoding]::GetEncoding(1252, [System.Text.EncoderFallback]::ExceptionFallback, [System.Text.DecoderFallback]::ExceptionFallback)
    $ponteiros = New-Object 'int[]' $quantidade
    for ($i=0; $i -lt $quantidade; $i++) {
        $ponteiros[$i] = [int][BitConverter]::ToUInt32($original, $i*12+8)
        if ($ponteiros[$i] -lt $inicio -or $ponteiros[$i] -ge $original.Length) { throw "Ponteiro invalido na entrada $i." }
        if ($i -gt 0 -and $ponteiros[$i] -le $ponteiros[$i-1]) { throw "Ponteiros fora de ordem na entrada $i." }
    }
    $mem = New-Object System.IO.MemoryStream
    $mem.Write($original,0,$inicio)
    $alteradas=0
    for ($i=0; $i -lt $quantidade; $i++) {
        $r=$registros[$i]
        if ([int]$r.id -ne $i) { throw "ID fora de ordem na linha $($i+2)." }
        $pos=$ponteiros[$i];$fim=$pos
        while ($fim -lt $original.Length -and $original[$fim] -ne 0) { $fim++ }
        if ($fim -ge $original.Length) { throw "String sem terminador na entrada $i." }
        $limite = if ($i -lt $quantidade-1) { $ponteiros[$i+1] } else { $original.Length }
        $padding = $limite - $fim - 1
        if ($padding -lt 0) { throw "Sobreposicao na entrada $i." }
        for ($j=$fim+1; $j -lt $limite; $j++) {
            if ($original[$j] -ne 0) { throw "Padding inesperado na entrada $i." }
        }
        $originalString=$encoding.GetString($original,$pos,$fim-$pos)
        if ($r.original_ingles -cne $originalString) { throw "Texto ingles divergente na entrada $i. Nao modifique a coluna original_ingles." }
        $texto=$r.traducao_ptbr_proposta
        if ([string]::IsNullOrWhiteSpace($texto)) { $texto=$originalString }
        if ($texto.Contains([char]0)) { throw "Caractere nulo na entrada $i." }
        $bytes=$encoding.GetBytes($texto)
        if ($texto -cne $originalString) { $alteradas++ }
        $novoOffset=[BitConverter]::GetBytes([uint32]$mem.Length)
        $mem.Position=$i*12+8
        $mem.Write($novoOffset,0,4)
        $mem.Position=$mem.Length
        $mem.Write($bytes,0,$bytes.Length)
        $mem.WriteByte(0)
        for ($j=0; $j -lt $padding; $j++) { $mem.WriteByte(0) }
    }
    [System.IO.File]::WriteAllBytes($saida,$mem.ToArray())
    $mem.Dispose()
    Write-Host "SUCESSO: text.eng gerado ($alteradas textos diferentes do ingles)." -ForegroundColor Green
    Write-Host "Arquivo: $saida"
    Write-Host 'Copie o text.eng para a pasta principal do jogo, apos fazer backup.'
    exit 0
} catch {
    Write-Host "ERRO: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
