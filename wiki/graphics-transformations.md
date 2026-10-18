# Graphics transformations and GrObj coordinates

GEOS TransMatrix uses row vectors: (x, y, 1) * M, with translation in
TM_e31/TM_e32. GrApplyScale and GrApplyRotation pre-multiply the current
GState matrix: M <- S*M and M <- R*M. Nonuniform scale and rotation do
not generally commute. The claim in TechDocs/Markdown/Concepts/cgraph.md,
section 23.5.2.2 (around lines 597-605), that arbitrary rotations and scalings
can be reordered is incorrect. Evidence: CInclude/graphics.h:TransMatrix;
Library/Kernel/Graphics/graphicsTransformUtils.asm:ScaleCommon, RotateCommon.

GeoDraw's scale UI sends MSG_GO_SCALE_OBJECT, which scales in object
coordinates: M <- S*M. Its rotate UI sends MSG_GO_ROTATE, whose GrObj
implementation rotates in parent coordinates: M <- M*R. Consequently,
scaling and rotating about the object center in either UI order produce
S*M*R (subject to fixed-point rounding). This does not imply S*R = R*S.
MSG_GO_SCALE is a different operation: it uses M <- M*S.
Evidence: Library/GrObj/UI/uiScaleControl.asm:OutputScaleCommon,
GrObjScaleControlCustomScale; Library/GrObj/UI/uiRotateControl.asm:
GrObjRotateControlRotate; Library/GrObj/GrObj/grobjGeometry.asm:
GrObjScaleObject, GrObjScale, GrObjRotate; Library/GrObj/GrObj/
grobjTransformUtils.asm:GrObjOTApplyScaleRelativeOBJECT,
GrObjOTApplyScaleRelative, GrObjOTApplyRotateRelative.
