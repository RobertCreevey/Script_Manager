function Resolve-Alias {
    <#
    .SYNOPSIS
        Resolves a name to its canonical form using alias lists.
    .DESCRIPTION
        Alias lists are arrays where [0] = canonical name, [1..n] = aliases.
        Used by routers, chain parser, tab completion, and help system.
    .PARAMETER Name
        The name to resolve (can be canonical or any alias).
    .PARAMETER AliasLists
        Hashtable of alias lists keyed by category (Actions, Parameters, Switches, Listeners, Builtins).
    .PARAMETER Category
        Category to search in. If omitted, searches all categories.
    .RETURNS
        PSCustomObject with Canonical, Category, and OriginalName. Returns null if not found.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)][string]$Name,
        [Parameter(Mandatory=$true)][hashtable]$AliasLists,
        [string]$Category
    )

    $Categories = if ($Category) { @($Category) } else { $AliasLists.Keys }

    foreach ($Cat in $Categories) {
        if (-not $AliasLists[$Cat]) { continue }
        foreach ($AliasList in $AliasLists[$Cat].Values) {
            if ($AliasList -contains $Name) {
                return [PSCustomObject]@{
                    Canonical     = $AliasList[0]
                    Category      = $Cat
                    OriginalName  = $Name
                    AllNames      = $AliasList
                }
            }
        }
    }
    return $null
}

function Get-CanonicalName {
    <#
    .SYNOPSIS
        Returns just the canonical name for a given name.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)][string]$Name,
        [Parameter(Mandatory=$true)][hashtable]$AliasLists,
        [string]$Category
    )
    $Result = Resolve-Alias -Name $Name -AliasLists $AliasLists -Category $Category
    return if ($Result) { $Result.Canonical } else { $Name }
}

function Get-AllNames {
    <#
    .SYNOPSIS
        Returns all names (canonical + aliases) for a category or all categories.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][hashtable]$AliasLists,
        [string]$Category
    )
    $Names = @()
    $Categories = if ($Category) { @($Category) } else { $AliasLists.Keys }
    foreach ($Cat in $Categories) {
        if ($AliasLists[$Cat]) {
            foreach ($AliasList in $AliasLists[$Cat].Values) {
                $Names += $AliasList
            }
        }
    }
    return $Names | Select-Object -Unique | Sort-Object
}

function New-AliasList {
    <#
    .SYNOPSIS
        Creates an alias list entry: @("canonical", "alias1", "alias2")
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Canonical,
        [string[]]$Aliases = @()
    )
    return @($Canonical) + $Aliases
}

function Merge-AliasLists {
    <#
    .SYNOPSIS
        Merges multiple alias list hashtables (later wins).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][hashtable[]]$Lists
    )
    $Merged = @{}
    foreach ($List in $Lists) {
        foreach ($Key in $List.Keys) {
            if (-not $Merged[$Key]) { $Merged[$Key] = @{} }
            foreach ($SubKey in $List[$Key].Keys) {
                $Merged[$Key][$SubKey] = $List[$Key][$SubKey]
            }
        }
    }
    return $Merged
}

Export-ModuleMember -Function Resolve-Alias, Get-CanonicalName, Get-AllNames, New-AliasList, Merge-AliasLists