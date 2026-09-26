{
    "name": "Nyx Demo Module",
    "version": "19.0.1.0.0",
    "summary": "Template custom module: model, views, menu, access rights.",
    "description": """
Copy this directory as the starting point for a real module:

    cp -r custom_addons/nyx_demo custom_addons/<your_module>

Then rename the model/menu/ACL prefixes and bump the version on every change.
""",
    "author": "Eden",
    "category": "Tools",
    "license": "LGPL-3",
    "depends": ["base", "web"],
    "data": [
        "security/ir.model.access.csv",
        "views/nyx_demo_views.xml",
    ],
    "installable": True,
    "application": True,
    "auto_install": False,
}
