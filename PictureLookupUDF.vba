Public Function PictureLookupUDF(FilePath As String, Location As Range, Index As Integer)

Dim lookupPicture As Shape
Dim sheetName As String
Dim pictureName As String
Dim sheetPath As String

pictureName = "PictureLookupUDF"

sheetName = Location.Parent.Name
sheetPath = ThisWorkbook.Path & "\"

'Delete current picture with the same Index if exists
For Each lookupPicture In Sheets(sheetName).Shapes
    If lookupPicture.Name = pictureName & Index Then
        lookupPicture.Delete
    End If
Next lookupPicture

'Add the picture in the right location
Set lookupPicture = Sheets(sheetName).Shapes.AddPicture _
(sheetPath & FilePath, msoFalse, msoTrue, Location.Left, Location.Top, -1, -1)

'Resize picture to best fit the range
If Location.Width / Location.Height > lookupPicture.Width / lookupPicture.Height Then
    lookupPicture.Height = Location.Height
Else
    lookupPicture.Width = Location.Width
End If

'change the picture name
lookupPicture.Name = pictureName & Index

PictureLookupUDF = "Picture Lookup: " & lookupPicture.Name

End Function
