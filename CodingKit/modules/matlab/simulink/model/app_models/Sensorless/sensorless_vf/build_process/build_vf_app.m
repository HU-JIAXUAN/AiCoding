function build_vf_app(outputModule)
%BUILD_VF_APP Assemble the standalone App from shared linked libraries.
module=fileparts(fileparts(mfilename('fullpath')));
if nargin==0,outputModule=module;end
root=fileparts(fileparts(fileparts(fileparts(module))));addpath(fullfile(root,'docs','scripts'),fullfile(module,'parameter'));
build_open_loop_app('vf',outputModule);
end
