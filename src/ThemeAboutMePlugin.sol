// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import "ocweb/contracts/src/interfaces/IVersionableWebsite.sol";
import "ocweb/contracts/src/interfaces/IDecentralizedApp.sol";

contract ThemeAboutMePlugin is ERC165, IVersionableWebsitePlugin {
    IDecentralizedApp public frontend;
    IVersionableWebsitePlugin public staticFrontendPlugin;

    constructor(IDecentralizedApp _frontend, IVersionableWebsitePlugin _staticFrontendPlugin) {
        frontend = _frontend;
        staticFrontendPlugin = _staticFrontendPlugin;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC165) returns (bool) {
        return
            interfaceId == type(IVersionableWebsitePlugin).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function infos() external view returns (Infos memory) {
        IVersionableWebsitePlugin[] memory dependencies = new IVersionableWebsitePlugin[](1);
        dependencies[0] = staticFrontendPlugin;

        return
            Infos({
                name: "themeAboutMe",
                version: "0.1.0",
                title: "Theme About Me",
                subTitle: "A theme for presenting oneself",
                author: "nand",
                homepage: "",
                dependencies: dependencies,
                adminPanels: new AdminPanel[](0)
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
        if (resource.length >= 1 && Strings.equal(resource[0], "admin")) {

            string[] memory newResource = new string[](resource.length - 1);
            for(uint j = 1; j < resource.length; j++) {
                newResource[j - 1] = resource[j];
            }

            (statusCode, body, headers) = frontend.request(newResource, params);

            return (statusCode, body, headers);
        }
    }

    function copyFrontendSettings(IVersionableWebsite website, uint fromFrontendIndex, uint toFrontendIndex) public {
        require(address(website) == msg.sender);
    }
}