import React from 'react';
import ReactDOM from 'react-dom';

import { shallow, configure } from 'enzyme';
import Adapter from 'enzyme-adapter-react-16';
configure({ adapter: new Adapter() });

import NodeInfo from 'forkMonitorApp/components/nodeInfo';
import MockCableApp from './__mocks__/cableAppMock';

let wrapper;

describe('NodeInfo', () => {
  const chaintip = {
    hash: "abcd",
    height: 500000,
    timestamp: 1,
    work: 86.000001
  }

  const node = {
    id: 1,
    name_with_version: "Bitcoin Core 0.17.1",
    best_block: chaintip,
    unreachable_since: null,
    ibd: false,
    height: 500000 - 2,
    os: "Linux"
  };

  beforeAll(() => {
    wrapper = shallow(<NodeInfo
      key={ 1 }
      node={ node }
      chaintip={ {block: chaintip} }
      cableApp={ MockCableApp }
    />)
    wrapper.setState({tooltipOpen: true})
  });

  test('should contain a tooltip', () => {
    expect(wrapper.text()).toContain("<Tooltip />");
  });

});
