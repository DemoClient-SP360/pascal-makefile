{ Copyright 2000-2005 The Apache Software Foundation or its licensors, as
 * applicable.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 }

//#include "ap_config.h"

{
 * @package Config Tree Package
 }

type
  Pap_directive_t = ^ap_directive_t;
  PPap_directive_t = ^Pap_directive_t;

{
 * Structure used to build the config tree.  The config tree only stores
 * the directives that will be active in the running server.  Directives
 * that contain other directions, such as <Directory ...> cause a sub-level
 * to be created, where the included directives are stored.  The closing
 * directive (</Directory>) is not stored in the tree.
 }
  ap_directive_t = record
    { The current directive }
    directive: PAnsiChar;
    { The arguments for the current directive, stored as a space
     *  separated list }
    args: PAnsiChar;
    { The next directive node in the tree
     *  @defvar ap_directive_t *next }
    next: Pap_directive_t;
    { The first child node of this directive
     *  @defvar ap_directive_t *first_child }
    first_child: Pap_directive_t;
    { The parent node of this directive
     *  @defvar ap_directive_t *parent }
    parent: Pap_directive_t;

    { directive's module can store add'l data here }
    data: Pointer;

    { ### these may go away in the future, but are needed for now }
    { The name of the file this directive was found in }
    filename: PAnsiChar;
    { The line number the directive was on }
    line_num: Integer;
  end;

{
 * The root of the configuration tree
 * @defvar ap_directive_t *conftree
 }
//AP_DECLARE_DATA extern ap_directive_t *ap_conftree;

{
 * Add a node to the configuration tree.
 * @param parent The current parent node.  If the added node is a first_child,
                 then this is changed to the current node
 * @param current The current node
 * @param toadd The node to add to the tree
 * @param child Is the node to add a child node
 * @return the added node
 }
//ap_directive_t *ap_add_node(ap_directive_t **parent, ap_directive_t *current,
//                            ap_directive_t *toadd, int child);

