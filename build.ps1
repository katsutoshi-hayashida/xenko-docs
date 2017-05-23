 param (
    [switch]$API
 )

# Remove build.log file
If(Test-Path build.log)
{
    Remove-Item build.log
}
Start-Transcript -Path build.log
# Generate API doc
if ($API)
{
    Write-Host "Generating API documentation..."
    
    # Build metadata from C# source
    deps\docfx\docfx.exe metadata

    Write-Host "Start Namespace build"
    function getNamespaceFilesLocation
    {
        # Check the source code location
        $projectLocationConfig = ((Get-Content docfx.json) | Select-String -Pattern '"cwd":').ToString().Trim() -split ":";
        $global:namespaceSrcLocation = $projectLocationConfig[1] -replace '[",\s]', '';
    }

    function getAllNamespaceFiles
    {    
        $global:namespaceFiles = Get-ChildItem "$namespaceSrcLocation" -Include "*Namespace*" -Recurse -Name
    }

    function getAllDescriptionFiles($searchTag)
    {
        $searchTagInner = "<" + $searchTag + ">" 
        for($i = 0; $i -lt $namespaceFiles.length; $i++){
            $currentFile = $namespaceFiles[$i]
            if(((Get-Content "$namespaceSrcLocation/$currentFile") | Select-String -Pattern $searchTagInner).length -gt 0){
               $global:descriptionFiles += $currentFile
            }
        }
    }

    function getDescription($searchTag)
    {
       $searchTagStart = "<" + $searchTag + ">"
       $searchTagEnd = "</" + $searchTag + ">"
       for($i = 0; $i -lt $descriptionFiles.length; $i++){
           $descriptionString = @();
           $currentFile = $descriptionFiles[$i]
           $currentFileContent = (Get-Content "$namespaceSrcLocation/$currentFile")

           $searchDescriptionStart = ( $currentFileContent | Select-String -Pattern $searchTagStart)
           $searchDescriptionEnd = ( $currentFileContent | Select-String -Pattern $searchTagEnd)
           $startStringNumber = $currentFileContent.IndexOf($searchDescriptionStart);
           $endStringNumber = $currentFileContent.IndexOf($searchDescriptionEnd);
           if($startStringNumber -eq $endStringNumber){
              $descriptionString = $currentFileContent[$startStringNumber] -replace '"', '\"'
           } else {
               for($j = $startStringNumber; $j -le $endStringNumber; $j++){
                    $descriptionString += $currentFileContent[$j] -replace '"', '\"'
               }
           }
           $global:descriptionStringArray += ($descriptionString -replace "[\n///]", '' -replace "$searchTagStart", "").Trim() | where {$_ -ne ""}
           $namespaceString = $currentFileContent | Select-String -Pattern 'namespace ';
           $global:descriptionFileNameArray +=  (($namespaceString -split '\s')[1]).Trim()
       }
    }

    function copyDescription($searchTag)
    {
        $folder = 'api/';
        $format = '.yml';
        for($i = 0; $i -lt $global:descriptionFileNameArray.Length; $i++){
            $currentFile = $global:descriptionFileNameArray[$i];
            if(Test-Path "$folder$currentFile$format"){
                $currentContent = (Get-Content "$folder$currentFile$format");
                if(($currentContent | Select-String -Pattern $searchTag).length -le 0){
                    $breakpoint = $currentContent.IndexOf('  children:');
                    $file = @();
                    for($j = 0; $j -lt $breakpoint; $j++){
                      $file += $currentContent[$j]
                    }
                    $file += "  "+ $searchTag + ": " + '"\n' + $global:descriptionStringArray[$i] + '\n"'
                    for($j = $breakpoint; $j -lt $currentContent.Length; $j++){
                      $file += $currentContent[$j]
                    }
                    $file | Out-file $folder$currentFile$format
                }
            }       
        }
    }

    getNamespaceFilesLocation
    getAllNamespaceFiles
    function setDescription($searchTag)
    {
        Write-Host "Set description for: $searchTag"
        $global:descriptionFiles = @();
		$global:descriptionStringArray = @();
		$global:descriptionFileNameArray = @();
        getAllDescriptionFiles($searchTag)
        getDescription($searchTag)
        copyDescription($searchTag)
    }
	$global:descriptionFiles = @(); # free memory
	$global:descriptionStringArray = @(); # free memory
	$global:descriptionFileNameArray = @(); # free memory

    $tagArray = 'remarks', 'summary';
	for($k = 0; $k -lt $tagArray.length; $k++){
       setDescription($tagArray[$k]) 
    }
	
	

    Write-Host "Generating types of items..."

    # Get all text from api/toc.yml
    $textYaml = (Get-Content api\toc.yml);
    # Set start variable for toc files source
    $folder = "api\"
    $format = ".yml"

    function setTypesToTOCItems($i){
		# Copy the uid string
		$global:temporaryTypeToc += $textYaml[$i] + "`n"
		
        # if string is uid of item 
        if($textYaml[$i].Contains('- uid:')){
            # Open file of this class and find type of the uid
            $lineEdited = $textYaml[$i].replace('- uid:', '').replace(' ', '').replace('`', '-')
            $content = (Get-Content "$folder$lineEdited$format");
            for($k = 0; $k -lt $content.length; $k++){
                if($content[$k].Contains('type:')){
                    if($textYaml[$i][0] -eq ' '){
                        $typeLine = $content[$k]
                        $global:temporaryTypeToc += "  $typeLine" + "`n"
                    } else {
                        $global:temporaryTypeToc += $typeLine + "`n"
                    }
                   break
                }
            }
		}
    }
	
	$global:temporaryTypeToc = "";
	for($lineCounter = 0; $lineCounter -lt $textYaml.length; $lineCounter++){
        setTypesToTOCItems($lineCounter);
    }

	($global:temporaryTypeToc) | Out-file api\toc.yml
	$global:temporaryTypeToc = ""; # free memory   

    function RegroupStructure($start){
        # Remember input string
        $inputStringNumber = $start;
        $lineIdeal = $textYaml[$arrayString[$start]];

       if($lineIdeal -eq '- uid: SiliconStudio' -OR $lineIdeal -eq '- uid: SiliconStudio.Xenko'){
            # Copy section
            $startPoint =  $arrayString[$start];
            $endPoint =  $arrayString[$start+1];
            for($k = $startPoint; $k -lt $endPoint; $k++){
                $textYaml[$k] | Out-file temporaryApiToc.yml -append
            }
           $breakpointDiff = $start + 1
           $breakpointDiff | Out-host
       } else {
            # Define the position of the "items"
            for($n = $arrayString[$start]; $n -lt $textYaml.length; $n++){
                $line = $textYaml[$n]
                if($line.length -gt 0){
                    if($line.Contains('items')){
                        $itemsStart = $n;
                        break
                    }
                }
            }

            # Find the equality breakpoint
            for($i = $start + 1; $i -lt $arrayString.length; $i++){
                $lineIdeal = $textYaml[$arrayString[$start]];
                $lineCurrent = $textYaml[$arrayString[$i]];
                Write-Host 'Checking on equality: ' 
                Write-Host "$lineCurrent -> $lineIdeal"
                if($lineCurrent.Contains($lineIdeal)){
                    Write-Host "$lineIdeal - processed successfully" 
                    $breakpointEqualPoint =  $arrayString[$i]
                    $needPad = "True"
                    break
                } else {
                    $breakpointEqualPoint =  $itemsStart+1
                    $needPad = "False"
                    continue
                }
            }

            $innerClasses = @();
            # Find the difference brakpoint
            for($i = $start; $i -lt $arrayString.length; $i++){
                $lineIdealName = $textYaml[$arrayString[$start] + 1].Replace('name:', '').Replace(' ', '') + '.';
                $lineCurrent = $textYaml[$arrayString[$i]];
                Write-Host 'Checking on difference: ' 
                Write-Host "$lineCurrent -> $lineIdeal"
                if($lineCurrent.Contains($lineIdeal)){
                    if($lineCurrent -ne $lineIdeal){
                        $innerClasses += $lineCurrent
                    }
                    continue
                } else {
                    Write-Host "$lineIdeal - processed successfully" 
                    $breakpointDiff = $i;
                    break
                }
            }

            # Set breakpoints variable
            $startPoint =  $arrayString[$start];
            $itemsStartPoint =  $itemsStart
            $itemsEndPoint =  $arrayString[$start + 1]
            $breakpointDiffPoint =  $arrayString[$breakpointDiff]

            # If we start from 0
            if($inputStringNumber -eq 0){
                for($k = $inputStringNumber; $k -lt $startPoint; $k++){
                    $textYaml[$k] | Out-file temporaryApiToc.yml -append
                }
            }

            # Copy from start to items
            for($k = $startPoint; $k -lt $itemsStartPoint; $k++){
                $textYaml[$k] | Out-file temporaryApiToc.yml -append
            }

            # Copy items string
            $textYaml[$itemsStartPoint] | Out-file temporaryApiToc.yml -append

            # Copy from equality to difference
            for($k = $breakpointEqualPoint; $k -lt $breakpointDiffPoint; $k++){
                $currentLine = $textYaml[$k];
                if($needPad -eq "True"){
                    if($currentLine.Contains('name:')){
                        $currentLine.PadLeft($currentLine.length + 2, " ").Replace($lineIdealName, '') | Out-file temporaryApiToc.yml -append
                    } else {
                        $currentLine.PadLeft($currentLine.length + 2, " ") | Out-file temporaryApiToc.yml -append
                    }
                } else {
                    $currentLine | Out-file temporaryApiToc.yml -append
                }
            }

            # Copy the rest of items
            for($k = $itemsStartPoint + 1; $k -lt $itemsEndPoint; $k++){
                $textYaml[$k] | Out-file temporaryApiToc.yml -append
            }

            $folder = "api\";
            $format = ".yml";
            $activeFile = $lineIdeal.Replace('- uid: ', '');
            "namespaces: Namespaces" | Out-file $folder$activeFile$format -append -Encoding ASCII
            "innerClasses:" | Out-file $folder$activeFile$format -append -Encoding ASCII
            for($i = 0; $i -lt $innerClasses.length; $i++){
                $addingClass = $innerClasses[$i]
                $addingClass.PadLeft($addingClass.length + 2, " ") | Out-file $folder$activeFile$format -append -Encoding ASCII
                $addingClass.PadLeft($addingClass.length + 2, " ").Replace('- uid', '  name').Replace($lineIdealName, '') | Out-file $folder$activeFile$format -append -Encoding ASCII
            }

            Remove-variable $inputStringNumber
            Remove-variable $lineIdeal
            Remove-variable $startPoint
            Remove-variable $endPoint
            Remove-variable $breakpointDiff
            Remove-variable $lineCurrent
            Remove-variable $breakpointEqualPoint
            Remove-variable $needPad
            Remove-variable $innerClasses
            Remove-variable $startPoint
            Remove-variable $itemsStartPoint
            Remove-variable $itemsEndPoint
            Remove-variable $breakpointDiffPoint
            Remove-variable $currentLine
            Remove-variable $folder
            Remove-variable $format
            Remove-variable $activeFile
        }
        
        if($breakpointDiff -lt $arrayString.length - 1){
            RegroupStructure($breakpointDiff)
        } else {
            # Copy from items string to end file
            for($k = $arrayString[$arrayString.length - 1]; $k -lt $textYaml.length; $k++){
                $textYaml[$k] | Out-file temporaryApiToc.yml -append
            }
            "### YamlMime regrouped" | Out-file temporaryApiToc.yml -append
            Write-Host "Regrouping the sub-namespaces complete"
        }
    }

    RegroupStructure(0)
    '' | Set-Content api\toc.yml
    (Get-Content temporaryApiToc.yml) | Set-Content api\toc.yml
    Remove-Item temporaryApiToc.yml

    # Remove SiliconStudio namespace prefix from TOC
    (Get-Content api\toc.yml).replace('  name: SiliconStudio.', '  name: ') | Set-Content api\toc.yml
}
else
{
    If(Test-Path api/.manifest)
    {
        Write-Host "Erasing API documentation..."
        Remove-Item api/*yml -recurse
        Remove-Item api/.manifest 
    }
}

Write-Host "Generating documentation..."

# Output to both build.log and console
deps\docfx\docfx.exe build

# Copy extra items
Copy-Item ReleaseNotes/ReleaseNotes.md _site/ReleaseNotes/
Copy-Item studio_getting_started_links.txt _site/
Stop-Transcript