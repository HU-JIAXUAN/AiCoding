function summary=run_if_app_validation(outputDirectory)
%RUN_IF_APP_VALIDATION Physical cases; JSON/CSV/PNG/SVG only, no MAT files.
if nargin<1,outputDirectory=fileparts(mfilename('fullpath'));end
summary=validate_open_loop_app('if',outputDirectory);
end
