$steps = @(
    @{ Eps = 20000;  Generators = 1 },
    @{ Eps = 50000;  Generators = 1 },
    @{ Eps = 100000; Generators = 2 },
    @{ Eps = 150000; Generators = 3 },
    @{ Eps = 200000; Generators = 4 },
    @{ Eps = 250000; Generators = 5 }
)

foreach ($repeat in 1..3) {
    foreach ($step in $steps) {
        .\scripts\run_step.ps1 -TotalEps $step.Eps -Generators $step.Generators -Repeat $repeat
    }
}
Write-Host "`nDONE. Results: results\steps.csv"