using namespace System;
using namespace System.Collections.Generic;
using namespace System.Windows.Controls;
using namespace System.Security;
using namespace System.Windows;
using namespace Microsoft;

# подключение сборок "WPF" и "WindowsForm" внутрь скрипта 
Add-Type -AssemblyName PresentationFramework;
Add-Type -AssemblyName System.Windows.Forms;

# перечисление типов проверяемых объектов в каталоге  
enum PathItemType { FolderItem = 1; FileItem }

# класс описывающий сущность разрешения на доступ 
class FileAccessModel
{
    [ValidateNotNullOrEmpty()] [System.String] $local:FileAccess;
    [ValidateNotNullOrEmpty()] [System.String] $local:AccessType;
    [ValidateNotNullOrEmpty()] [System.String] $local:AccountName;
}

# класс описывающий сущность объекта директории
class FilePathModel
{
    [System.String] $local:FileExtension;
    [System.String] $local:FilePathName;
    [System.String] $local:FilePathFullName;
    
    # статический метод для создания объекта на основе полного путя 
    static [FilePathModel] CreateFromItemPath([System.String] $item_path, [PathItemType] $item_type)
    {
        [System.String[]] $local:item_path_split = $item_path.Split(@('\'));
        [System.String[]] $local:item_ext_split = $item_path_split[$item_path_split.Lenght - 1].Split('.');
        
        [System.String] $local:itemext_str = [System.String]::Empty;
        [System.String] $local:itempath_str = [System.String]::Empty;

        switch($item_type)
        {
            FolderItem {
                $local:itemext_str = [System.String]::new("Folder");
                $local:itempath_str = $local:item_path_split[$local:item_path_split.Length - 1];
            }
            FileItem {
                $local:itemext_str = $local:item_ext_split[$local:item_ext_split.Length - 1];
                for([int]$local:i = 0; $i -lt $local:item_ext_split.Length - 1; $i++)
                {
                    $local:itempath_str += ($local:item_ext_split[$i]);
                }
            }
        }
        return [FilePathModel]@{
            FileExtension = $itemext_str; FilePathName = $itempath_str; FilePathFullName = $item_path;
        }
    }
}
# функция для загрузки представления из xaml - созданиет объект System.Windows.Window
function local:LoadXamlFormFile([string] ${local:File-Path})
{
    [Xml.XmlDocument] ${local:Xaml-File} = (Get-Content -Path ${local:File-Path});
    [Xml.XmlNodeReader] ${local:Xaml-Reader} = (New-Object System.Xml.XmlNodeReader ${Xaml-File});
    return ([Windows.Markup.XamlReader]::Load(${Xaml-Reader}));
}

# создание объект GUI окна
try { ${script:Main-Window} = local:LoadXamlFormFile("$PSScriptRoot\view.xaml"); }
catch { Write-Host("Can't load Windows.Markup.XamlReader; $($PSItem.Exteption.Message)"); Exit; }

# получаем ссылку на необходимые списки ListView из окна 
[ListView] ${script:File-ListView} = ${script:Main-Window}.FindName("FileItemsListView");
[ListView] ${script:Access-ListView} = ${script:Main-Window}.FindName("AccessListView");

# добавление обработки на собатие выбора элемента из списка  
${script:File-ListView}.Add_MouseUp({
    [AccessControl.NativeObjectSecurity] $local:file_security = (Get-Acl -Path (
        ${script:File-ListView}.Items[${script:File-ListView}.SelectedIndex].FilePathFullName));
    ${script:Access-ListView}.Items.Clear();

    ${script:Main-Window}.FindName("OwnerNameTextBox").Text = $local:file_security.Owner
    ${script:Main-Window}.FindName("FullNameFileTextBox").Text = 
        ${File-ListView}.Items[${File-ListView}.SelectedIndex].FilePathFullName
        
    foreach($local:item in $file_security.Access) {
        ${script:Access-ListView}.Items.Add([FileAccessModel]@{
            AccountName = $local:item.IdentityReference;
            FileAccess = $local:item.FileSystemRights;
            AccessType = $local:item.AccessControlType;
        });
    }
});

# добавление обработки на собатие выбора элемента из списка 
${script:Access-ListView}.Add_MouseUp({
    ${script:Main-Window}.FindName("AccessRightsTextBox").Text = 
        ${Access-ListView}.Items[${script:Access-ListView}.SelectedIndex].FileAccess;
    ${script:Main-Window}.FindName("AccessTypeTextBox").Text = 
        ${Access-ListView}.Items[${script:Access-ListView}.SelectedIndex].AccessType;
    ${script:Main-Window}.FindName("AccountNameTextBox").Text = 
        ${Access-ListView}.Items[${script:Access-ListView}.SelectedIndex].AccountName;
});

# добавление обработки на собатие нажатия на кнопку
${script:Main-Window}.FindName("ChooseFilePathButton").Add_Click({
    [Forms.FolderBrowserDialog] $local:filepath_dialog = [Forms.FolderBrowserDialog]::new();
    if(($local:filepath_dialog).ShowDialog() -ne [Forms.DialogResult]::OK )
    {
        [MessageBox]::Show("Cannot Open FilePath", "Error"); return [void];
    }

    ${script:File-ListView}.Items.Clear();
    ${script:Access-ListView}.Items.Clear();

    [IO.Directory]::GetDirectories($local:filepath_dialog.SelectedPath) | ForEach-Object -Process {
        ${script:File-ListView}.Items.Add([FilePathModel]::CreateFromItemPath($PSItem, [PathItemType]::FolderItem));
    };

    [IO.Directory]::GetFiles($local:filepath_dialog.SelectedPath) | ForEach-Object -Process {
        ${script:File-ListView}.Items.Add([FilePathModel]::CreateFromItemPath($PSItem, [PathItemType]::FileItem));
    };
    
})

# открываем окно
${script:Main-Window}.ShowDialog() | Out-Null;