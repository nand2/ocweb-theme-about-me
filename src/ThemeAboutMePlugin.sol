// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import "ocweb/contracts/src/interfaces/IVersionableWebsite.sol";
import "ocweb/contracts/src/interfaces/IDecentralizedApp.sol";
import "./library/LibStrings.sol";

contract ThemeAboutMePlugin is ERC165, IVersionableWebsitePlugin {
    IDecentralizedApp public frontend;
    IVersionableWebsitePlugin public staticFrontendPlugin;
    IVersionableWebsitePlugin public ocWebAdminPlugin;

    struct Config {
        string[] rootPath;
    }
    mapping(IVersionableWebsite => mapping(uint => Config)) private configs;

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

    uint public adminPanelUrlCacheKey = 0;
    function bumpAdminPanelUrlCache() public /** No access control deemed necessary */ {
        if(adminPanelUrlCacheKey == type(uint).max) {
            adminPanelUrlCacheKey = 0;
        }
        adminPanelUrlCacheKey++;
    }

    function infos() external view returns (Infos memory) {
        IVersionableWebsitePlugin[] memory dependencies = new IVersionableWebsitePlugin[](2);
        dependencies[0] = staticFrontendPlugin;
        dependencies[1] = ocWebAdminPlugin;

        AdminPanel[] memory adminPanels = new AdminPanel[](1);
        adminPanels[0] = AdminPanel({
            title: "Theme About Me",
            url: string.concat("/themes/about-me/admin.umd.js?cacheKey=", Strings.toString(adminPanelUrlCacheKey)),
            moduleForGlobalAdminPanel: ocWebAdminPlugin,
            panelType: AdminPanelType.Secondary
        });
        // adminPanels[1] = AdminPanel({
        //     title: "Theme About Me",
        //     url: "/themes/about-me/admin.umd.js",
        //     moduleForGlobalAdminPanel: ocWebAdminPlugin,
        //     panelType: AdminPanelType.Secondary
        // });

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
        // Serve the admin parts : /themes/about-me/* -> /themes/about-me/*
        if(resource.length >= 2 && Strings.equal(resource[0], "themes") && Strings.equal(resource[1], "about-me")) {
            (statusCode, body, headers) = frontend.request(resource, params);

            return (statusCode, body, headers);
        }

        // Serve the frontend : Proxy /[config.rootPath]/* -> /*
        Config memory config = configs[website][websiteVersionIndex];
        if(resource.length >= config.rootPath.length) {
            bool prefixMatch = true;
            for(uint i = 0; i < config.rootPath.length; i++) {
                if(Strings.equal(resource[i], config.rootPath[i]) == false) {
                    prefixMatch = false;
                    break;
                }
            }

            if(prefixMatch) {
                string[] memory newResource = new string[](resource.length - config.rootPath.length);
                for(uint i = 0; i < resource.length - config.rootPath.length; i++) {
                    newResource[i] = resource[i + config.rootPath.length];
                }

                (statusCode, body, headers) = frontend.request(newResource, params);

                // If there is a "Cache-control: evm-events" header, we will replace it with 
                // "Cache-control: evm-events=<addressOfFrontend><newResourcePath>"
                // We only include <newResourcePath> if config.rootPath is not empty, otherwise the
                // path of the cache clearing event will be the same than the path of the URL
                // That way, we indicate that the contract emitting the cache clearing events is 
                // the frontend website
                for(uint i = 0; i < headers.length; i++) {
                    if(LibStrings.compare(headers[i].key, "Cache-control") && LibStrings.compare(headers[i].value, "evm-events")) {
                        string memory path = "";
                        string memory cacheDirectiveValueQuote = "";
                        if(config.rootPath.length > 0) {
                            cacheDirectiveValueQuote = "\"";
                            path = "/";
                            for(uint j = 0; j < newResource.length; j++) {
                                path = string.concat(path, newResource[j]);
                                if(j < newResource.length - 1) {
                                    path = string.concat(path, "/");
                                }
                            }
                        }

                        headers[i].value = string.concat("evm-events=", cacheDirectiveValueQuote, LibStrings.toHexString(address(frontend)), path, cacheDirectiveValueQuote);
                    }
                }

                return (statusCode, body, headers);
            }
        }
    }

    function copyFrontendSettings(IVersionableWebsite website, uint fromFrontendIndex, uint toFrontendIndex) public {
        require(address(website) == msg.sender);

        Config storage config = configs[website][toFrontendIndex];
        Config storage fromConfig = configs[website][fromFrontendIndex];

        config.rootPath = fromConfig.rootPath;
    }

    function getConfig(IVersionableWebsite website, uint websiteVersionIndex) external view returns (Config memory) {
        return configs[website][websiteVersionIndex];
    }

    function setConfig(IVersionableWebsite website, uint websiteVersionIndex, Config memory _config) external {
        require(address(website) == msg.sender || website.owner() == msg.sender, "Not the owner");

        require(website.isLocked() == false, "Website is locked");

        require(websiteVersionIndex < website.getWebsiteVersionCount(), "Website version out of bounds");
        IVersionableWebsite.WebsiteVersion memory websiteVersion = website.getWebsiteVersion(websiteVersionIndex);
        require(websiteVersion.locked == false, "Website version is locked");

        Config storage config = configs[website][websiteVersionIndex];

        config.rootPath = _config.rootPath;
    }
}