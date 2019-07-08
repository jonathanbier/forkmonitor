import React from 'react';
import ReactDOM from 'react-dom';

import { shallow, configure } from 'enzyme';
import Adapter from 'enzyme-adapter-react-16';
configure({ adapter: new Adapter() });

import Chaintip from 'forkMonitorApp/components/chaintip';


const mockNodes = [
    {id: 1, name: "Bitcoin Core", version: 170100, height: 500000, unreachable_since: null, ibd: false},
    {id: 2, name: "Bitcoin Core", version: 160300, height: 500000, unreachable_since: null, ibd: false}
]

const chaintip = {
    block: {
        hash: "abcd",
        height: 500000,
        timestamp: 1,
        work: 86.000001
    },
    nodes: mockNodes
}

describe('rendered component', () => {

  const wrapper = shallow(<Chaintip
    key={ chaintip.hash }
    chaintip={ chaintip }
    nodes={ mockNodes }
    index={ 0 }
    last={ true }
  />);

  test('should contain two nodes', () => {
    expect(wrapper.find('.node-info')).toHaveLength(2);
  });
});
