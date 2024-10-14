function transformed_pointset = TransformPointset(pointset, transform)
%
%   Returns the TRANSFORMed pointset 
%
%   TRANSFORMED_POINTSET = TRANSFORM_POINTSET(POINTSET, TRANSFORM)
%

transformed_pointset = homo2cart((transform * cart2homo(pointset)')');
