// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import "ocweb/contracts/src/interfaces/IVersionableWebsite.sol";
import "ocweb/contracts/src/interfaces/IDecentralizedApp.sol";

contract ThemeAboutMePlugin is ERC165, IVersionableWebsitePlugin {
    IDecentralizedApp public frontend;
    IVersionableWebsitePlugin public staticFrontendPlugin;
    IVersionableWebsitePlugin public ocWebAdminPlugin;

    constructor(IDecentralizedApp _frontend, IVersionableWebsitePlugin _staticFrontendPlugin, IVersionableWebsitePlugin _ocWebAdminPlugin) {
        frontend = _frontend;
        staticFrontendPlugin = _staticFrontendPlugin;
        ocWebAdminPlugin = _ocWebAdminPlugin;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC165) returns (bool) {
        return
            interfaceId == type(IVersionableWebsitePlugin).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function infos() external view returns (Infos memory) {
        IVersionableWebsitePlugin[] memory dependencies = new IVersionableWebsitePlugin[](2);
        dependencies[0] = staticFrontendPlugin;
        dependencies[1] = ocWebAdminPlugin;

        AdminPanel[] memory adminPanels = new AdminPanel[](1);
        adminPanels[0] = AdminPanel({
            title: "Theme About Me",
            url: "/themes/about-me/admin.umd.js",
            moduleForGlobalAdminPanel: ocWebAdminPlugin,
            panelType: AdminPanelType.Primary
        });

        return
            Infos({
                name: "themeAboutMe",
                version: "0.1.0",
                title: "Theme About Me",
                subTitle: "A theme for presenting oneself",
                author: "nand",
                homepage: "web3://ocweb.eth/",
                dependencies: dependencies,
                adminPanels: adminPanels
            });
    }

    function rewriteWeb3Request(IVersionableWebsite website, uint websiteVersionIndex, string[] memory resource, KeyValue[] memory params) external view returns (bool rewritten, string[] memory newResource, KeyValue[] memory newParams) {
        return (false, new string[](0), new KeyValue[](0));
    }

    function processWeb3Request(
        IVersionableWebsite website,
        uint websiteVersionIndex,
        string[] memory resource,
        KeyValue[] memory params
    )
        external view override returns (uint statusCode, string memory body, KeyValue[] memory headers)
    {
        // Serve the admin plugin : /themes/about-me/[admin.umd.js|admin.css] -> /admin/[admin.umd.js|admin.css]
        if (resource.length == 3 && Strings.equal(resource[0], "themes") && Strings.equal(resource[1], "about-me") && (Strings.equal(resource[2], "admin.umd.js") || Strings.equal(resource[2], "admin.css"))) {

            string[] memory newResource = new string[](2);
            newResource[0] = "admin";
            newResource[1] = resource[2];

            (statusCode, body, headers) = frontend.request(newResource, params);

            return (statusCode, body, headers);
        }

        // Serve the frontend : /* -> /*
        (uint newStatusCode, string memory newBody, KeyValue[] memory newHeaders) = frontend.request(resource, params);
        if(newStatusCode == 200) {
            return (newStatusCode, newBody, newHeaders);
        }
    }

    function copyFrontendSettings(IVersionableWebsite website, uint fromFrontendIndex, uint toFrontendIndex) public {
        require(address(website) == msg.sender);
    }
}