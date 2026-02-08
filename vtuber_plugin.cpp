#include <obs-module.h>
#include <util/text-lookup.h>
#include "VtuberPlugin.hpp"

OBS_DECLARE_MODULE()

/* Custom locale: no dependency on locale/en-US.ini so plugin loads even when
   OBS data path differs (e.g. bin/64bit vs install root). Strings show as keys. */
static void *obs_module_lookup = NULL;

const char *obs_module_text(const char *val)
{
	const char *out = val;
	if (obs_module_lookup)
		text_lookup_getstr((lookup_t *)obs_module_lookup, val, &out);
	return out;
}

MODULE_EXPORT bool obs_module_get_string(const char *val, const char **out)
{
	if (obs_module_lookup && text_lookup_getstr((lookup_t *)obs_module_lookup, val, out))
		return true;
	*out = val;
	return false;
}

MODULE_EXPORT void obs_module_set_locale(const char *)
{
	if (obs_module_lookup) {
		text_lookup_destroy((lookup_t *)obs_module_lookup);
		obs_module_lookup = NULL;
	}
	/* Optionally try default locale file; if missing, plugin still works */
	char *path = obs_module_file("locale/en-US.ini");
	if (path) {
		lookup_t *lookup = text_lookup_create(path);
		bfree(path);
		if (lookup)
			obs_module_lookup = lookup;
	}
}

MODULE_EXPORT void obs_module_free_locale(void)
{
	if (obs_module_lookup) {
		text_lookup_destroy((lookup_t *)obs_module_lookup);
		obs_module_lookup = NULL;
	}
}

MODULE_EXPORT const char *obs_module_description(void)
{
	return "Bongo Cat";
}

bool obs_module_load(void)
{
	obs_source_info Vtuber_video{
	};
	Vtuber_video.id = "bongobs-cat";
	Vtuber_video.type = OBS_SOURCE_TYPE_INPUT;
	Vtuber_video.output_flags = OBS_SOURCE_VIDEO;
	Vtuber_video.get_name =
		VtuberPlugin::VtuberPlugin::VtuberGetName;
	Vtuber_video.create =
		VtuberPlugin::VtuberPlugin::VtuberCreate;
	Vtuber_video.destroy =
		VtuberPlugin::VtuberPlugin::VtuberDestroy;
	Vtuber_video.video_render =
		VtuberPlugin::VtuberPlugin::VtuberRender;
	Vtuber_video.get_width =
		VtuberPlugin::VtuberPlugin::VtuberWidth;
	Vtuber_video.get_height =
		VtuberPlugin::VtuberPlugin::VtuberHeight;
	Vtuber_video.get_properties =
		VtuberPlugin::VtuberPlugin::VtuberGetProperties;
	Vtuber_video.update =
		VtuberPlugin::VtuberPlugin::Vtuber_update;
	Vtuber_video.get_defaults =
		VtuberPlugin::VtuberPlugin::Vtuber_defaults;

	obs_register_source(&Vtuber_video);

	return true;
}

#ifdef _WIN32
void obs_module_unload(void)
{

}
#endif
