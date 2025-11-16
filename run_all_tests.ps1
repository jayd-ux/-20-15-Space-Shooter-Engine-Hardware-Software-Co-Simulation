# run_all_tests.ps1
# Compiles and runs all 4 Verilog testbenches + opens GTKWave if available.

$tests = @(
    @{ tb = "game_tb.v";    out = "tb1vvp"; vcd = "tb1.vcd"; name="TB1 (Perfect Hit)" },
    @{ tb = "game_tb2.v";   out = "tb2vvp"; vcd = "tb2.vcd"; name="TB2 (Left Edge)" },
    @{ tb = "game_tb3.v";   out = "tb3vvp"; vcd = "tb3.vcd"; name="TB3 (Miss & Retry)" },
    @{ tb = "game_tb4.v";   out = "tb4vvp"; vcd = "tb4.vcd"; name="TB4 (Right Edge)" }
)

# Check tool existence
function Check-Tool($exe) {
    $cmd = Get-Command $exe -ErrorAction SilentlyContinue
    if (-not $cmd) {
        Write-Host "ERROR: '$exe' not found in PATH." -ForegroundColor Red
        exit 1
    }
}

Check-Tool "iverilog"
Check-Tool "vvp"

# Check GTKWave
$gtkwaveCmd = Get-Command gtkwave -ErrorAction SilentlyContinue

if (-not $gtkwaveCmd) {
    Write-Host "GTKWave not found in PATH."
    $gtkwavePath = Read-Host "Enter full path to gtkwave.exe (leave blank to skip)"
    
    if ($gtkwavePath -and (Test-Path $gtkwavePath)) {
        $gtkwave = $gtkwavePath
    } else {
        Write-Host "GTKWave disabled."
        $gtkwave = $null
    }
} else {
    $gtkwave = $gtkwaveCmd.Path
}

# Run all tests
foreach ($t in $tests) {
    $tb = $t.tb
    $out = $t.out
    $vcd = $t.vcd
    $name = $t.name

    Write-Host "---------------------------------------------"
    Write-Host "Compiling ${name}  ($tb)"

    $compileArgs = @("-o", $out, "game_design.v", $tb)
    $process = Start-Process -FilePath "iverilog" -ArgumentList $compileArgs `
        -NoNewWindow -Wait -PassThru `
        -RedirectStandardOutput ".\compile_$out.log" `
        -RedirectStandardError  ".\compile_$out.err"

    if ($process.ExitCode -ne 0) {
        Write-Host "Compilation failed for $tb" -ForegroundColor Red
        continue
    }

    Write-Host "Running simulation for ${name} ..."
    $runProc = Start-Process -FilePath "vvp" -ArgumentList $out `
        -NoNewWindow -Wait -PassThru `
        -RedirectStandardOutput ".\run_$out.log" `
        -RedirectStandardError  ".\run_$out.err"

    $stdout = Get-Content ".\run_$out.log"

    Write-Host ""
    Write-Host "===== Simulation Output for ${name} ====="
    $stdout | ForEach-Object { Write-Host $_ }
    Write-Host "========================================="
    Write-Host ""

    # ---------------------------------------
    # PASS / FAIL CHECK (corrected)
    # ---------------------------------------
    $score = $null

    foreach ($line in $stdout) {
        if ($line -match "score=([0-9]+)") {
            $score = [int]$Matches[1]
        }
    }

    if ($score -ne $null) {
        if ($score -ge 1) {
            Write-Host "$name => PASS" -ForegroundColor Green
        }
        else {
            Write-Host "$name => FAIL" -ForegroundColor Red
        }
    }
    else {
        Write-Host "$name => FAIL (score not found)" -ForegroundColor Red
    }

    # Launch GTKWave if available
    if ($gtkwave -and (Test-Path $vcd)) {
        Write-Host "Opening $vcd in GTKWave..."
        Start-Process -FilePath $gtkwave -ArgumentList $vcd
    }
}

Write-Host "All tests completed."
