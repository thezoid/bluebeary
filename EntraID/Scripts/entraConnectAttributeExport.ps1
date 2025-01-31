$outpath = "c:\temp\$(get-date -format "yyyyMMMdd")adconnecysyncrules.csv"
if (test-path $outpath) { remove-item $outpath -force -Confirm:$false }
$syncrules = get-adsyncrule
#foreach sync rule in adc
foreach ($rule in $syncrules) {
     #for each attr flow map in sync rule
     foreach ($flow in $rule.AttributeFlowMappings) {
          $obj = [PSCustomObject]@{
               RuleName         = $rule.name
               RuleDirection    = $rule.Direction
               RulePrecedence   = $rule.Precedence
               RuleIsCustom     = !$rule.IsStandardRule
               RuleDisabled     = $rule.Disabled
               ADAttribute      = $flow.MappingSourceAsString
               EntraIDAttribute = $flow.destination
               Expression       = $flow.expression
          }
          $obj | export-csv -nti $outpath -Append
     }
}

