
#define NRD_CONSTANTS_START(name) cbuffer _NRDConstants {
#define NRD_CONSTANT(type,name) type name;
#define NRD_CONSTANTS_END };
#define NRD_INPUTS_START
#define NRD_INPUT(type,dataType,name,reg,binding,policy) type<dataType> name; NRD_DECLARE_RESOURCE(name,policy)
#define NRD_INPUTS_END
#define NRD_OUTPUTS_START
#define NRD_OUTPUT(type,dataType,name,reg,binding,policy) type<dataType> name; NRD_DECLARE_RESOURCE(name,policy)
#define NRD_OUTPUTS_END
#define NRD_SAMPLERS_START
#define gNearestClamp sampler_point_clamp
#define gLinearClamp sampler_linear_clamp
#define NRD_SAMPLER(type,name,reg,binding) type name;
#define NRD_SAMPLERS_END
